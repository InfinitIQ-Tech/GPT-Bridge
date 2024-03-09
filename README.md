# GPT-Bridge
Welcome to GPT-Bridge! GPT-Bridge is a powerful, yet lightweight framework that bridges the gap between Swift and the OpenAI assistant's API.
<details>
  <summary>Installation</summary>
  
Add the Swift Package via Swift Package Manager:

  - Navigate to the project navigator by clicking on the blue project icon on the top of the left sidebar.
  - Select your project, not the target, to open project settings.
  - Click on the Swift Packages tab near the center top of the window.
    - Click the + button below the list of packages to add a new package.
    - When prompted for the package repository URL, enter: https://github.com/InfinitIQ-Tech/GPT-Bridge
    - Click Next.
  - Specify the Version Rules:
  
    Xcode will automatically attempt to find the most recent version of the package that is compatible with your project. However, you can specify a different version or even a branch or commit if needed.

  - You will be presented with a list of products provided by the package. GPT-Bridge should be selected. If not, select it.
  - Choose the target in your project where you want to use GPT-Bridge. This is typically your main application target.
  - Click Finish to add the package to your project.
</details>

<details>
  <summary>Setup</summary>
  Before use of GPTBridge, ensure you've provided your OpenAI API key and the key for the assistant you'll be using:  
   
  `NOTE`: It's recommended to do this at app launch to avoid any potential timing issues.
  
  ```swift
  GPTBridge.appLaunch(openAIAPIKey: "sk-mykey", assistantKey: "my-assistant-key")
  ```
</details>

<details>
  <summary>Usage</summary>
1. Create a thread
  
  A thread holds messages from the user to the assistant and from the assistant to the user.

  ```swift
  let threadId = try await GPTBridge.createThread()
  ```

2. Add a message from the user to the thread

  ```swift
  try await GPTBridge.addMessageToThread(message: "Message from user", threadId: threadId, role: .user)
  ```

3. Create a Run 

  A run is where an assistant determines what tools to run and runs them. If no tools are run, the assistant generates a message

  ```swift
  let runId = try await GPTBridge.createRun(threadId: threadId)
  ```

  - NOTE: only 1 run can be active in a thread at once. If a run is active and another is created, the previous run will be cancelled.

4. Poll for run status - wait for the assistant to use tools and/or come back with a response

  ```swift
  let runStepResult = try await GPTBridge.pollRunStatus(runId: runId)
  ```

5. Handle the response.

  - If tools were run, the `functions` parameter of the returned `RunStepResult` will be populated
    
  - If a message was generated, the `message` parameter of the returned `RunStepResult` will be populated
  
  - NOTE: Both `functions` and `message` should never be populated in this version, but may be in future versions

  ```swift
  // Check if the assistant performed any actions that resulted in functions being executed
if let actionResults = runStepResult.functions {
    // Assume your assistant has a function to generate and upload an image
    // Try to get the image title and prompt used to generate the image, both generated by your assistant
    guard let imageTitle = actionResults.first?.arguments["photo_name"]?.asString,
          let imagePrompt = actionResults.first?.arguments["prompt"]?.asString else {
        print("Missing information for image generation.")
        return
    }

    // Generate the image based on the prompt and upload it
    let uploadedImageUrl = "[URL of the uploaded image]"

    // Prepare the message including uploaded image to show to the user
    let displayMessage = "Here's an image based on: \(imagePrompt)"

    // Display the message with the image to the user
    print(displayMessage)
    print("Image URL: \(uploadedImageUrl)")

} else if let textMessage = runStepResult.message {
    // If the assistant returned a simple message, display it to the user
    print("Assistant says: \(textMessage)")
}
  ```
</details>