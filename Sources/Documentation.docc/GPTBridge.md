# ``GPTBridge``

GPTBridge is a powerful tool that allows you to interact with Open AI Custom GPTs (assistants), such as the "Maze Generator" assistant, which generates text for detailed, immersive maze adventures.

## Topics

### Usage

#### Maze Generator Assistant

The assistant has these instructions:

"""
You are 'Maze Master'. You are an expert in weaving an interactive adventure within a nearly endless dungeon maze, focusing on rich, detailed descriptions of magical and medieval environments.

The GPT blends realistic medieval elements with magical aspects, creating a sense of wonder and intrigue. It provides vivid descriptions and images of locations, architectures, and magical elements, guiding users through a complex, ever-changing maze.

The interaction style is mysterious and enigmatic, enhancing the sense of discovery and adventure. Maze Master's storytelling is formal, with a tone that adds to the mystique of the dungeon, making each narrative and choice part of an immersive and enigmatic experience.

You will describe the room the user is in followed by descriptions of “exits” they can take from that room.
"""

The assistant also has a function "exits" which outputs the current room's exits in a string array, such as `["N", "S", "E"]`

```
{
"name": "exits",
"description": "Provide cardinal directions of all described exits",
"parameters": {
  "type": "object",
  "properties": {
    "exits": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "The cardinal directions of the available exits"
    }
  },
  "required": [
    "exits"
  ]
}
}
```

#### Getting Started

To get started, you need to provide your OpenAI API key and assistant key. This is recommended at app launch and required before making any calls using GPTBridge:

```
GPTBridge.appLaunch(openAIAPIKey: "your_openai_api_key", assistantKey: "your_assistant_key")
```

#### Creating a Thread

To begin a conversation with the assistant, create a new thread:

```
let threadId = try await GPTBridge.createThread()
```

#### Adding Messages to the Thread

You can add messages to the thread using the `addMessageToThread` function:

```
try await GPTBridge.addMessageToThread(message: "Generate the maze's first room", threadId: threadId)
```

#### Creating a Run

To get the assistant to process the thread (including previous messages and function results up to the context limit), create a new run:

```
let runId = try await GPTBridge.createRun(threadId: threadId)
```

#### Polling for Run Status

The assistant takes some time to process the run and may choose to use tools (functions), generate a message, retrieve a file it has stored in its knowledgebase, or a combination. After creating a run, poll for the run status to retrieve the assistant's response:

```
let result = try await GPTBridge.pollRunStatus(threadId: threadId, runId: runId)
```

The `pollRunStatus` function returns a `RunStepResult`, which can be either a `FunctionRunStepResult` or a `MessageRunStepResult`.

#### Handling Function Calls

If the assistant requires additional information, it will return a `FunctionRunStepResult` containing the function call details. In the case of the "Maze Master" assistant, it has a single function called `exits`, which describes the available exits from the current room.

You can handle the function call like this:

```
guard let function = result.functions?[0] else {
   print(result.message ?? "Nothing happened!")
   return
}
let message = result.message ?? "You have fallen into the pit of despair. Adventure over."
print(message) // display message to user
let toolCallId = function.toolCallId
let functionName = function.name
let functionParameters = function.functionParameters
if let exits = functionParameters["exits"]?.asArray<String> {
   print(exits) // use these exits to present buttons, etc to the user so the user can choose
}
// user chooses an exit, submit the result back to the assistant so the assistant can generate the next room's description:
let userChoice = exits[0]

let userChoiceArgument: FunctionArgument = FunctionArgument(userChoice)
let toolOutput = ["user_choice": userChoiceArgument]

let nextRoomResult = try await GPTBridge.submitToolOutputs(
    threadId: threadId,
    runId: runId,
    toolCallId: toolCallId,
    toolOutputs: toolOutput
)
```

#### Handling Assistant Messages

If the assistant generates a message response, it will be returned in the `RunStepResult`. You can access the message like this:

```
if let message = result.message {
   print(message)
}
```

By following these steps and handling the different types of results, you can engage in an interactive conversation with the "Maze Master" assistant, exploring the vast and mysterious maze it generates.
