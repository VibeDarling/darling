/*
This file is part of Darling.

Copyright (C) 2026 Darling Developers

Darling is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Darling is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

// AUGraph: audio units by description, wired together. Opening the graph makes the units;
// connections and input callbacks become the destination units' MakeConnection and
// SetRenderCallback properties; starting and stopping it starts and stops its output units.

#include <AudioToolbox/AUGraph.h>
#include <AudioToolbox/AudioComponent.h>
#include <AudioToolbox/AudioOutputUnit.h>
#include <CarbonCore/MacErrors.h>
#include <mutex>
#include <vector>

namespace {

struct Node
{
	AUNode id;
	AudioComponentDescription description;
	AudioUnit unit;
};

}

struct OpaqueAUGraph
{
	std::recursive_mutex lock;
	std::vector<Node> nodes;
	std::vector<AUNodeInteraction> interactions;
	AUNode nextNode = 1;
	bool open = false, initialized = false, running = false;

	Node* find(AUNode id)
	{
		for (Node& node : nodes)
			if (node.id == id)
				return &node;
		return nullptr;
	}
};

using Lock = std::lock_guard<std::recursive_mutex>;

static OSStatus instantiate(Node& node)
{
	AudioComponent component = AudioComponentFindNext(nullptr, &node.description);
	if (component == nullptr)
		return kAUGraphErr_InvalidAudioUnit;
	return AudioComponentInstanceNew(component, &node.unit);
}

static AUNode destinationOf(const AUNodeInteraction& interaction)
{
	return interaction.nodeInteractionType == kAUNodeInteraction_Connection
		? interaction.nodeInteraction.connection.destNode
		: interaction.nodeInteraction.inputCallback.destNode;
}

static UInt32 destinationInputOf(const AUNodeInteraction& interaction)
{
	return interaction.nodeInteractionType == kAUNodeInteraction_Connection
		? interaction.nodeInteraction.connection.destInputNumber
		: interaction.nodeInteraction.inputCallback.destInputNumber;
}

// Makes one interaction a property of its destination unit; with clear, undoes it.
static OSStatus apply(AUGraph graph, const AUNodeInteraction& interaction, bool clear)
{
	Node* dest = graph->find(destinationOf(interaction));
	if (dest == nullptr || dest->unit == nullptr)
		return kAUGraphErr_NodeNotFound;
	if (interaction.nodeInteractionType == kAUNodeInteraction_Connection)
	{
		const AUNodeConnection& c = interaction.nodeInteraction.connection;
		Node* source = graph->find(c.sourceNode);
		if (source == nullptr || source->unit == nullptr)
			return kAUGraphErr_NodeNotFound;
		AudioUnitConnection connection = { clear ? nullptr : source->unit, c.sourceOutputNumber, c.destInputNumber };
		return AudioUnitSetProperty(dest->unit, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input,
			c.destInputNumber, &connection, sizeof(connection));
	}
	AURenderCallbackStruct callback = interaction.nodeInteraction.inputCallback.cback;
	if (clear)
		callback = AURenderCallbackStruct{ nullptr, nullptr };
	return AudioUnitSetProperty(dest->unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input,
		interaction.nodeInteraction.inputCallback.destInputNumber, &callback, sizeof(callback));
}

// An input takes one interaction: a new one replaces what was there.
static OSStatus addInteraction(AUGraph graph, const AUNodeInteraction& interaction)
{
	Lock lock(graph->lock);
	if (graph->find(destinationOf(interaction)) == nullptr)
		return kAUGraphErr_NodeNotFound;
	if (interaction.nodeInteractionType == kAUNodeInteraction_Connection
		&& graph->find(interaction.nodeInteraction.connection.sourceNode) == nullptr)
		return kAUGraphErr_NodeNotFound;
	for (auto it = graph->interactions.begin(); it != graph->interactions.end(); ++it)
	{
		if (destinationOf(*it) == destinationOf(interaction) && destinationInputOf(*it) == destinationInputOf(interaction))
		{
			if (graph->open)
				apply(graph, *it, true);
			graph->interactions.erase(it);
			break;
		}
	}
	graph->interactions.push_back(interaction);
	return graph->open ? apply(graph, interaction, false) : noErr;
}

extern "C" {

OSStatus NewAUGraph(AUGraph* outGraph)
{
	if (outGraph == nullptr)
		return paramErr;
	*outGraph = new OpaqueAUGraph;
	return noErr;
}

OSStatus DisposeAUGraph(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	AUGraphStop(inGraph);
	AUGraphUninitialize(inGraph);
	AUGraphClose(inGraph);
	delete inGraph;
	return noErr;
}

OSStatus AUGraphAddNode(AUGraph inGraph, const AudioComponentDescription* inDescription, AUNode* outNode)
{
	if (inGraph == nullptr || inDescription == nullptr || outNode == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	Node node = { inGraph->nextNode++, *inDescription, nullptr };
	if (inGraph->open)
	{
		OSStatus status = instantiate(node);
		if (status != noErr)
			return status;
		if (inGraph->initialized)
			AudioUnitInitialize(node.unit);
	}
	inGraph->nodes.push_back(node);
	*outNode = node.id;
	return noErr;
}

OSStatus AUGraphNewNode(AUGraph inGraph, const struct ComponentDescription* inDescription, UInt32 inClassDataSize,
	const void* inClassData, AUNode* outNode)
{
	// A Carbon ComponentDescription is laid out as an AudioComponentDescription.
	return AUGraphAddNode(inGraph, reinterpret_cast<const AudioComponentDescription*>(inDescription), outNode);
}

OSStatus AUGraphRemoveNode(AUGraph inGraph, AUNode inNode)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	for (auto it = inGraph->interactions.begin(); it != inGraph->interactions.end();)
	{
		bool touches = destinationOf(*it) == inNode
			|| (it->nodeInteractionType == kAUNodeInteraction_Connection && it->nodeInteraction.connection.sourceNode == inNode);
		if (touches)
		{
			if (inGraph->open)
				apply(inGraph, *it, true);
			it = inGraph->interactions.erase(it);
		}
		else
			++it;
	}
	for (auto it = inGraph->nodes.begin(); it != inGraph->nodes.end(); ++it)
	{
		if (it->id == inNode)
		{
			if (it->unit != nullptr)
			{
				if (inGraph->initialized)
					AudioUnitUninitialize(it->unit);
				AudioComponentInstanceDispose(it->unit);
			}
			inGraph->nodes.erase(it);
			return noErr;
		}
	}
	return kAUGraphErr_NodeNotFound;
}

OSStatus AUGraphGetNodeCount(AUGraph inGraph, UInt32* outNumberOfNodes)
{
	if (inGraph == nullptr || outNumberOfNodes == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	*outNumberOfNodes = UInt32(inGraph->nodes.size());
	return noErr;
}

OSStatus AUGraphGetIndNode(AUGraph inGraph, UInt32 inIndex, AUNode* outNode)
{
	if (inGraph == nullptr || outNode == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (inIndex >= inGraph->nodes.size())
		return kAUGraphErr_NodeNotFound;
	*outNode = inGraph->nodes[inIndex].id;
	return noErr;
}

OSStatus AUGraphNodeInfo(AUGraph inGraph, AUNode inNode, AudioComponentDescription* outDescription, AudioUnit* outAudioUnit)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	Node* node = inGraph->find(inNode);
	if (node == nullptr)
		return kAUGraphErr_NodeNotFound;
	if (outDescription != nullptr)
		*outDescription = node->description;
	if (outAudioUnit != nullptr)
		*outAudioUnit = node->unit;
	return noErr;
}

OSStatus AUGraphGetNodeInfo(AUGraph inGraph, AUNode inNode, struct ComponentDescription* outDescription,
	UInt32* outClassDataSize, void** outClassData, AudioUnit* outAudioUnit)
{
	if (outClassDataSize != nullptr)
		*outClassDataSize = 0;
	if (outClassData != nullptr)
		*outClassData = nullptr;
	return AUGraphNodeInfo(inGraph, inNode, reinterpret_cast<AudioComponentDescription*>(outDescription), outAudioUnit);
}

OSStatus AUGraphConnectNodeInput(AUGraph inGraph, AUNode inSourceNode, UInt32 inSourceOutputNumber, AUNode inDestNode,
	UInt32 inDestInputNumber)
{
	if (inGraph == nullptr)
		return paramErr;
	if (inSourceNode == inDestNode)
		return kAUGraphErr_InvalidConnection;
	AUNodeInteraction interaction = {};
	interaction.nodeInteractionType = kAUNodeInteraction_Connection;
	interaction.nodeInteraction.connection = { inSourceNode, inSourceOutputNumber, inDestNode, inDestInputNumber };
	return addInteraction(inGraph, interaction);
}

OSStatus AUGraphSetNodeInputCallback(AUGraph inGraph, AUNode inDestNode, UInt32 inDestInputNumber,
	const AURenderCallbackStruct* inInputCallback)
{
	if (inGraph == nullptr || inInputCallback == nullptr)
		return paramErr;
	AUNodeInteraction interaction = {};
	interaction.nodeInteractionType = kAUNodeInteraction_InputCallback;
	interaction.nodeInteraction.inputCallback = { inDestNode, inDestInputNumber, *inInputCallback };
	return addInteraction(inGraph, interaction);
}

OSStatus AUGraphDisconnectNodeInput(AUGraph inGraph, AUNode inDestNode, UInt32 inDestInputNumber)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	for (auto it = inGraph->interactions.begin(); it != inGraph->interactions.end(); ++it)
	{
		if (destinationOf(*it) == inDestNode && destinationInputOf(*it) == inDestInputNumber)
		{
			if (inGraph->open)
				apply(inGraph, *it, true);
			inGraph->interactions.erase(it);
			return noErr;
		}
	}
	return noErr;
}

OSStatus AUGraphClearConnections(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (inGraph->open)
		for (const AUNodeInteraction& interaction : inGraph->interactions)
			apply(inGraph, interaction, true);
	inGraph->interactions.clear();
	return noErr;
}

OSStatus AUGraphGetNumberOfInteractions(AUGraph inGraph, UInt32* outNumInteractions)
{
	if (inGraph == nullptr || outNumInteractions == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	*outNumInteractions = UInt32(inGraph->interactions.size());
	return noErr;
}

OSStatus AUGraphGetInteractionInfo(AUGraph inGraph, UInt32 inInteractionIndex, AUNodeInteraction* outInteraction)
{
	if (inGraph == nullptr || outInteraction == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (inInteractionIndex >= inGraph->interactions.size())
		return paramErr;
	*outInteraction = inGraph->interactions[inInteractionIndex];
	return noErr;
}

OSStatus AUGraphCountNodeInteractions(AUGraph inGraph, AUNode inNode, UInt32* outNumInteractions)
{
	if (inGraph == nullptr || outNumInteractions == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	UInt32 count = 0;
	for (const AUNodeInteraction& interaction : inGraph->interactions)
		if (destinationOf(interaction) == inNode
			|| (interaction.nodeInteractionType == kAUNodeInteraction_Connection && interaction.nodeInteraction.connection.sourceNode == inNode))
			count++;
	*outNumInteractions = count;
	return noErr;
}

OSStatus AUGraphGetNodeInteractions(AUGraph inGraph, AUNode inNode, UInt32* ioNumInteractions, AUNodeInteraction* outInteractions)
{
	if (inGraph == nullptr || ioNumInteractions == nullptr || outInteractions == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	UInt32 count = 0;
	for (const AUNodeInteraction& interaction : inGraph->interactions)
	{
		if (count == *ioNumInteractions)
			break;
		if (destinationOf(interaction) == inNode
			|| (interaction.nodeInteractionType == kAUNodeInteraction_Connection && interaction.nodeInteraction.connection.sourceNode == inNode))
			outInteractions[count++] = interaction;
	}
	*ioNumInteractions = count;
	return noErr;
}

OSStatus AUGraphOpen(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (inGraph->open)
		return noErr;
	for (Node& node : inGraph->nodes)
	{
		OSStatus status = instantiate(node);
		if (status != noErr)
		{
			for (Node& made : inGraph->nodes)
				if (made.unit != nullptr)
				{
					AudioComponentInstanceDispose(made.unit);
					made.unit = nullptr;
				}
			return status;
		}
	}
	inGraph->open = true;
	for (const AUNodeInteraction& interaction : inGraph->interactions)
		apply(inGraph, interaction, false);
	return noErr;
}

OSStatus AUGraphClose(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (!inGraph->open)
		return noErr;
	AUGraphStop(inGraph);
	AUGraphUninitialize(inGraph);
	for (Node& node : inGraph->nodes)
		if (node.unit != nullptr)
		{
			AudioComponentInstanceDispose(node.unit);
			node.unit = nullptr;
		}
	inGraph->open = false;
	return noErr;
}

OSStatus AUGraphInitialize(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (!inGraph->open)
		return kAUGraphErr_CannotDoInCurrentContext;
	if (inGraph->initialized)
		return noErr;
	for (Node& node : inGraph->nodes)
	{
		OSStatus status = AudioUnitInitialize(node.unit);
		if (status != noErr)
			return status;
	}
	inGraph->initialized = true;
	return noErr;
}

OSStatus AUGraphUninitialize(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (!inGraph->initialized)
		return noErr;
	AUGraphStop(inGraph);
	for (Node& node : inGraph->nodes)
		AudioUnitUninitialize(node.unit);
	inGraph->initialized = false;
	return noErr;
}

// Starting the graph starts its output units: they pull the rest through the connections.
OSStatus AUGraphStart(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (inGraph->running)
		return noErr;
	if (!inGraph->initialized)
	{
		OSStatus status = AUGraphInitialize(inGraph);
		if (status != noErr)
			return status;
	}
	bool output = false;
	for (Node& node : inGraph->nodes)
	{
		if (node.description.componentType != kAudioUnitType_Output)
			continue;
		OSStatus status = AudioOutputUnitStart(node.unit);
		if (status != noErr)
			return status;
		output = true;
	}
	if (!output)
		return kAUGraphErr_OutputNodeErr;
	inGraph->running = true;
	return noErr;
}

OSStatus AUGraphStop(AUGraph inGraph)
{
	if (inGraph == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (!inGraph->running)
		return noErr;
	for (Node& node : inGraph->nodes)
		if (node.description.componentType == kAudioUnitType_Output)
			AudioOutputUnitStop(node.unit);
	inGraph->running = false;
	return noErr;
}

OSStatus AUGraphIsOpen(AUGraph inGraph, Boolean* outIsOpen)
{
	if (inGraph == nullptr || outIsOpen == nullptr)
		return paramErr;
	*outIsOpen = inGraph->open;
	return noErr;
}

OSStatus AUGraphIsInitialized(AUGraph inGraph, Boolean* outIsInitialized)
{
	if (inGraph == nullptr || outIsInitialized == nullptr)
		return paramErr;
	*outIsInitialized = inGraph->initialized;
	return noErr;
}

OSStatus AUGraphIsRunning(AUGraph inGraph, Boolean* outIsRunning)
{
	if (inGraph == nullptr || outIsRunning == nullptr)
		return paramErr;
	*outIsRunning = inGraph->running;
	return noErr;
}

// Changes apply when they are made, so there is never anything left to update.
OSStatus AUGraphUpdate(AUGraph inGraph, Boolean* outIsUpdated)
{
	if (inGraph == nullptr)
		return paramErr;
	if (outIsUpdated != nullptr)
		*outIsUpdated = true;
	return noErr;
}

// Render notifications go to the output units, which render the whole graph.
OSStatus AUGraphAddRenderNotify(AUGraph inGraph, AURenderCallback inCallback, void* inRefCon)
{
	if (inGraph == nullptr || inCallback == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	if (!inGraph->open)
		return kAUGraphErr_CannotDoInCurrentContext;
	for (Node& node : inGraph->nodes)
		if (node.description.componentType == kAudioUnitType_Output)
			return AudioUnitAddRenderNotify(node.unit, inCallback, inRefCon);
	return kAUGraphErr_OutputNodeErr;
}

OSStatus AUGraphRemoveRenderNotify(AUGraph inGraph, AURenderCallback inCallback, void* inRefCon)
{
	if (inGraph == nullptr || inCallback == nullptr)
		return paramErr;
	Lock lock(inGraph->lock);
	for (Node& node : inGraph->nodes)
		if (node.description.componentType == kAudioUnitType_Output && node.unit != nullptr)
			return AudioUnitRemoveRenderNotify(node.unit, inCallback, inRefCon);
	return kAUGraphErr_OutputNodeErr;
}

// The graph does not measure the time its units take.
OSStatus AUGraphGetCPULoad(AUGraph inGraph, Float32* outAverageCPULoad)
{
	if (inGraph == nullptr || outAverageCPULoad == nullptr)
		return paramErr;
	*outAverageCPULoad = 0;
	return noErr;
}

OSStatus AUGraphGetMaxCPULoad(AUGraph inGraph, Float32* outMaxLoad)
{
	if (inGraph == nullptr || outMaxLoad == nullptr)
		return paramErr;
	*outMaxLoad = 0;
	return noErr;
}

}
