# OpenAI Agents SDK Integration Plan for GPT-Bridge

## Executive Summary

This document outlines a concrete plan to incorporate agentic workflows from the OpenAI Agents Python SDK into the GPT-Bridge Swift framework. Based on direct analysis of the [OpenAI Agents Python SDK](https://github.com/openai/openai-agents-python), this plan provides actionable steps to extend GPT-Bridge's current Assistant API capabilities with proven multi-agent orchestration patterns.

## SDK Analysis Summary

### Core Architecture Components Identified

**1. Agent Definition (`src/agents/agent.py`)**
- `Agent` class with: `name`, `instructions`, `tools`, `handoffs`, `input_guardrails`, `output_guardrails`, `output_type`
- Dynamic instructions via callable functions
- MCP (Model Context Protocol) server integration for external tools
- Agent-as-tool pattern via `as_tool()` method

**2. Execution Engine (`src/agents/run.py`)**
- `Runner` class with static methods: `run()`, `run_sync()`, `run_streamed()`
- `AgentRunner` internal implementation with agent loop logic
- Context management through `RunContextWrapper` 
- Turn-based execution with `max_turns` limit
- Built-in usage tracking and tracing

**3. Handoffs System (`src/agents/handoffs.py`)**
- Handoffs implemented as **specialized tool calls** 
- `Handoff` dataclass with `tool_name`, `tool_description`, `input_json_schema`, `on_invoke_handoff`
- `HandoffInputFilter` for modifying conversation history between agents
- Automatic agent name resolution and validation

**4. Guardrails System (`src/agents/guardrail.py`)**
- `InputGuardrail` and `OutputGuardrail` classes with decorator support
- **Parallel execution** with the main agent loop
- **"Tripwire" mechanism** - guardrails can immediately halt execution
- `GuardrailFunctionOutput` with `tripwire_triggered` boolean

**5. Tool Integration (`src/agents/tool.py`)**
- `FunctionTool` with automatic schema generation
- MCP tool integration via `HostedMCPTool`
- Built-in tools: `ComputerTool`, `FileSearchTool`, `WebSearchTool`, `ImageGenerationTool`
- Tool use behavior configuration: `"run_llm_again"`, `"stop_on_first_tool"`, custom functions

### Proven Agentic Patterns from Examples

**From `examples/agent_patterns/`:**
1. **Deterministic Flows** (`deterministic.py`): Sequential agent chaining with output passing
2. **Routing** (`routing.py`): Triage agent selecting specialized agents based on input classification  
3. **Agents as Tools** (`agents_as_tools.py`): Agents calling other agents as function tools
4. **LLM-as-a-Judge** (`llm_as_a_judge.py`): Self-evaluation agents rating and improving outputs
5. **Parallelization** (`parallelization.py`): Concurrent agent execution with result aggregation
6. **Forcing Tool Use** (`forcing_tool_use.py`): Tool choice control and structured outputs

**From `examples/customer_service/main.py`:**
- Real-world triage pattern: General agent → Billing agent → Account management agent
- Handoff with context preservation and input filtering
- Multi-turn conversations with state management

## Current GPT-Bridge Assessment

### Existing Capabilities
- **Assistant API Integration**: Thread/message management, run execution 
- **Run Handler Pattern**: `FunctionRunHandler`, `MessageRunHandler`, `FailureRunHandler`
- **Tool Support**: DallE integration, function calling
- **HTTP Layer**: `RequestManager`, structured error handling
- **Type Safety**: Swift Codable models, async/await patterns

### Architecture Strengths
1. **Clean Separation**: Request management, models, and handlers are well-separated
2. **Extensibility**: Run handler protocol allows custom behavior
3. **Swift-First Design**: Native concurrency and type safety
4. **SOLID Principles**: Single responsibility, dependency injection patterns

## Integration Strategy

### Phase 1: Core Agent Foundation (15-23 developer days)

**Objective**: Establish basic agent functionality compatible with current GPT-Bridge architecture

#### 1.1 Agent Model Implementation (5-8 days)
**Reference**: `src/agents/agent.py` from SDK

Create Swift equivalent of Python Agent class:
```swift
public struct Agent {
    public let id: String
    public let name: String
    public let instructions: AgentInstructions
    public let tools: [Tool]
    public let handoffs: [HandoffReference]
    public let inputGuardrails: [InputGuardrail]
    public let outputGuardrails: [OutputGuardrail]
    public let outputType: AgentOutputType?
    public let modelSettings: ModelSettings
}

public enum AgentInstructions {
    case static(String)
    case dynamic(AgentInstructionsFunction)
}

public typealias AgentInstructionsFunction = (RunContext, Agent) async -> String
```

**Key Implementation Details**:
- Support both static and dynamic instructions (matching Python SDK's callable instructions)
- Handoff references use string-based agent lookup (not direct references)
- Model settings inheritance and override capability
- Tool enabling/disabling via context-sensitive functions

#### 1.2 Agent Runner Implementation (8-12 days)
**Reference**: `src/agents/run.py` - `AgentRunner` class and agent loop logic

Core runner matching Python SDK's execution model:
```swift
public class AgentRunner {
    public static func run(
        startingAgent: Agent,
        input: String,
        context: RunContext?,
        maxTurns: Int = 10,
        runConfig: RunConfig = .default
    ) async throws -> RunResult
    
    public static func runStreamed(
        startingAgent: Agent,
        input: String,
        context: RunContext?,
        maxTurns: Int = 10,
        runConfig: RunConfig = .default
    ) -> RunResultStreaming
}
```

**Critical Agent Loop Implementation** (based on Python `_run_single_turn`):
1. **LLM Invocation**: Call model with system prompt, conversation history, tools
2. **Response Processing**: Parse for final output, handoffs, or tool calls
3. **Tool Execution**: Execute function/handoff tools in parallel where possible
4. **Context Update**: Add new items to conversation and update usage tracking
5. **Loop Decision**: Continue, handoff to new agent, or terminate with final output

#### 1.3 Run Context and State Management (2-3 days)
**Reference**: `src/agents/run_context.py` and context handling in `_run_impl.py`

```swift
public class RunContext {
    public var usage: Usage
    public var conversationHistory: [RunItem]
    public var metadata: [String: Any]
    
    // Thread-safe context updates during agent execution
    public func updateUsage(_ newUsage: Usage)
    public func addRunItem(_ item: RunItem)
}

public class RunContextWrapper<T> {
    public let context: T?
    public let runContext: RunContext
}
```

### Phase 2: Handoffs Implementation (8-12 days)

**Objective**: Implement the handoff mechanism exactly as designed in Python SDK

#### 2.1 Handoff Tool Implementation (5-8 days)
**Reference**: `src/agents/handoffs.py` - handoffs are specialized tools

Key insight: **Handoffs are tool calls, not a separate mechanism**
```swift
public struct Handoff {
    public let toolName: String
    public let toolDescription: String  
    public let inputJSONSchema: [String: Any]
    public let onInvokeHandoff: HandoffFunction
    public let agentName: String
    public let inputFilter: HandoffInputFilter?
}

public typealias HandoffFunction = (RunContextWrapper, String) async throws -> Agent
```

**Critical Implementation**: 
- Handoffs appear as regular function tools to the LLM
- When invoked, they return a new agent and optionally filter conversation history
- Input filtering allows removing/modifying messages before handoff (privacy, context pruning)

#### 2.2 Agent Registry and Resolution (3-4 days)
**Reference**: Agent lookup patterns in customer_service example

```swift
public class AgentRegistry {
    private var agents: [String: Agent] = [:]
    
    public func register(_ agent: Agent)
    public func resolve(_ agentName: String) throws -> Agent
    public func createHandoff(to agent: Agent) -> Handoff
}
```

### Phase 3: Guardrails System (7-10 days)

**Objective**: Implement parallel guardrail execution with tripwire mechanism

#### 3.1 Guardrail Base Implementation (4-6 days)
**Reference**: `src/agents/guardrail.py` - parallel execution with tripwires

```swift
public protocol InputGuardrail {
    func validate(
        agent: Agent,
        input: String,
        context: RunContextWrapper
    ) async -> GuardrailResult
}

public struct GuardrailResult {
    public let outputInfo: Any?
    public let tripwireTriggered: Bool
}
```

**Key Implementation Detail**: Guardrails run **in parallel** with main agent execution, not sequentially. They can trigger "tripwires" that immediately halt agent execution.

#### 3.2 Guardrail Parallel Execution (3-4 days)
**Reference**: `_run_input_guardrails` in Python SDK using `asyncio.gather()`

```swift
// Swift Task.withTaskGroup equivalent to Python asyncio.gather
func runInputGuardrails(
    agent: Agent,
    guardrails: [InputGuardrail],
    input: String,
    context: RunContextWrapper
) async throws -> [GuardrailResult] {
    
    return try await withThrowingTaskGroup(of: GuardrailResult.self) { group in
        for guardrail in guardrails {
            group.addTask {
                return await guardrail.validate(agent: agent, input: input, context: context)
            }
        }
        
        var results: [GuardrailResult] = []
        for try await result in group {
            if result.tripwireTriggered {
                // Cancel remaining tasks and throw exception
                group.cancelAll()
                throw GuardrailTripwireTriggered(result)
            }
            results.append(result)
        }
        return results
    }
}
```

### Phase 4: Advanced Agentic Patterns (12-18 days)

**Objective**: Implement proven patterns from SDK examples

#### 4.1 Agents-as-Tools Pattern (4-6 days)  
**Reference**: `examples/agent_patterns/agents_as_tools.py` and `Agent.as_tool()` method

```swift
extension Agent {
    public func asTool(
        name: String? = nil,
        description: String? = nil,
        outputExtractor: ((RunResult) async -> String)? = nil
    ) -> FunctionTool {
        return FunctionTool { (context: RunContextWrapper, input: String) -> String in
            let result = try await AgentRunner.run(
                startingAgent: self,
                input: input,
                context: context.context
            )
            
            if let extractor = outputExtractor {
                return await extractor(result)
            }
            return result.finalOutput as? String ?? ""
        }
    }
}
```

#### 4.2 Deterministic Workflow Builder (4-6 days)
**Reference**: `examples/agent_patterns/deterministic.py`

```swift
public class AgentWorkflow {
    private var steps: [(Agent, String)] = []
    
    public func addStep(agent: Agent, prompt: String) -> Self {
        steps.append((agent, prompt))
        return self
    }
    
    public func execute(initialInput: String, context: RunContext? = nil) async throws -> RunResult {
        var currentInput = initialInput
        var allItems: [RunItem] = []
        
        for (agent, prompt) in steps {
            let stepInput = prompt.replacingOccurrences(of: "{input}", with: currentInput)
            let result = try await AgentRunner.run(
                startingAgent: agent,
                input: stepInput,
                context: context
            )
            
            allItems.append(contentsOf: result.newItems)
            currentInput = result.finalOutput as? String ?? ""
        }
        
        return RunResult(
            input: initialInput,
            newItems: allItems,
            finalOutput: currentInput,
            context: context
        )
    }
}
```

#### 4.3 LLM-as-a-Judge Implementation (4-6 days)
**Reference**: `examples/agent_patterns/llm_as_a_judge.py`

```swift
public struct JudgeWorkflow {
    public let worker: Agent
    public let judge: Agent
    public let maxIterations: Int
    
    public func execute(input: String, context: RunContext? = nil) async throws -> RunResult {
        var currentOutput = input
        var allItems: [RunItem] = []
        
        for iteration in 0..<maxIterations {
            // Worker produces output
            let workerResult = try await AgentRunner.run(
                startingAgent: worker,
                input: currentOutput,
                context: context
            )
            
            // Judge evaluates output
            let judgeInput = "Evaluate this output: \(workerResult.finalOutput)"
            let judgeResult = try await AgentRunner.run(
                startingAgent: judge,
                input: judgeInput,
                context: context
            )
            
            allItems.append(contentsOf: workerResult.newItems)
            allItems.append(contentsOf: judgeResult.newItems)
            
            // Check if judge approves (implementation specific)
            if judgeApproves(judgeResult.finalOutput) {
                return RunResult(/* final approved result */)
            }
            
            currentOutput = extractFeedback(judgeResult.finalOutput)
        }
        
        // Return best attempt after max iterations
        return RunResult(/* fallback result */)
    }
}
```

## API Design Philosophy

### Public API Simplicity (Following Uncle Bob's Principles)

The public-facing API must be extremely simple and intuitive:

```swift
// Basic single agent
let agent = Agent(name: "Assistant", instructions: "You are helpful")
let result = try await AgentRunner.run(agent: agent, input: "Hello")

// Multi-agent handoff workflow  
let triage = Agent(name: "Triage", instructions: "Route to appropriate agent")
    .addHandoff(to: spanishAgent)
    .addHandoff(to: englishAgent)

let result = try await AgentRunner.run(agent: triage, input: "Hola")

// Deterministic workflow
let workflow = AgentWorkflow()
    .addStep(agent: researcher, prompt: "Research: {input}")
    .addStep(agent: writer, prompt: "Write article about: {input}")
    .addStep(agent: editor, prompt: "Edit this article: {input}")

let result = try await workflow.execute(initialInput: "Swift concurrency")
```

### Internal Architecture Flexibility

Internal implementation follows established GPT-Bridge patterns:
- **Protocol-based design** for all major components (agents, tools, guardrails)
- **Dependency injection** through RunConfig and context
- **Single Responsibility Principle** with focused, testable components
- **Comprehensive error handling** with structured error types

## Integration with Existing GPT-Bridge Architecture

### Backward Compatibility Strategy
- **Existing API Unchanged**: Current `GPTBridge` class remains fully functional
- **Incremental Migration**: Developers can adopt agent features gradually
- **Shared Infrastructure**: Reuse existing `RequestManager`, `HTTPClient`, and model definitions

### Enhanced Run Handler Pattern
```swift
// Extend existing run handler protocol for agent support
protocol AgentRunHandler: RunHandler {
    var agentContext: AgentContext { get }
    func handleHandoff() async throws -> Agent?
    func validateOutput() async throws -> Bool
}

// New agent-aware run handlers
class HandoffRunHandler: AgentRunHandler { /* ... */ }
class GuardrailRunHandler: AgentRunHandler { /* ... */ }
```

### Request Management Integration
```swift
// Extend existing endpoint system
extension AssistantEndpoint {
    case agentRun(AgentRunRequest)
    case agentHandoff(HandoffRequest)
}

// Reuse existing HTTP infrastructure
class AgentRequestManager {
    private let requestManager: RequestManager
    
    func executeAgentRun(_ request: AgentRunRequest) async throws -> AgentRunResponse {
        // Leverage existing RequestManager for HTTP handling
        return try await requestManager.performRequest(endpoint: .agentRun(request))
    }
}
```

## Testing Strategy

### Unit Testing Coverage
Based on Python SDK test patterns:

1. **Agent Configuration Validation**
   - Invalid instruction formats
   - Tool compatibility checks
   - Handoff reference resolution

2. **Runner Execution Logic**
   - Turn limit enforcement
   - Context state management
   - Error propagation through agent chains

3. **Handoff Mechanics**
   - Agent resolution and invocation
   - Input filtering behavior
   - Context preservation across handoffs

4. **Guardrail Functionality**
   - Parallel execution timing
   - Tripwire triggering and recovery
   - Output validation accuracy

### Integration Testing Scenarios
Real-world patterns from SDK examples:

1. **Customer Service Workflow**
   - Triage → Billing → Account Management flow
   - Context preservation through multiple handoffs
   - Error handling when agent unavailable

2. **Research Pipeline**
   - Research → Analysis → Writing → Review chain
   - Output quality validation at each step
   - Parallel fact-checking guardrails

3. **Code Generation Workflow**
   - Specification → Implementation → Testing → Documentation
   - LLM-as-a-judge pattern for code quality
   - Deterministic execution with retry logic

## Migration Path from Current GPT-Bridge

### Phase 1: Compatibility Layer
```swift
// Extend existing GPTBridge class with agent support
extension GPTBridge {
    public func runAgent(
        agent: Agent,
        input: String,
        context: Any? = nil
    ) async throws -> AgentResult {
        // Bridge to new AgentRunner while maintaining existing API patterns
        let runContext = RunContext(context: context)
        let result = try await AgentRunner.run(
            startingAgent: agent,
            input: input,
            context: runContext
        )
        return AgentResult(from: result)
    }
}
```

### Phase 2: Enhanced Assistant Integration
```swift
// Agents as enhanced assistants
extension Assistant {
    public func asAgent() -> Agent {
        return Agent(
            name: self.name ?? "Assistant",
            instructions: .static(self.instructions),
            tools: self.tools.map { $0.asAgentTool() },
            // Convert assistant configuration to agent configuration
        )
    }
}
```

### Phase 3: Pure Agent API
```swift
// New agent-first API alongside existing assistant API
public class AgentBridge {
    public init(apiKey: String, configuration: AgentConfiguration = .default)
    
    public func run(agent: Agent, input: String) async throws -> AgentResult
    public func runWorkflow(_ workflow: AgentWorkflow) async throws -> WorkflowResult
    public func registerAgent(_ agent: Agent)
}
```

## Implementation Timeline and Effort Estimates

### Total Effort: 50-75 developer days

**Phase 1: Core Agent Foundation** (15-23 days)
- **Agent Model**: 5-8 days - Medium complexity, requires careful Swift API design
- **Agent Runner**: 8-12 days - High complexity, core execution engine with proper async handling
- **Context Management**: 2-3 days - Medium complexity, thread-safe state management

**Phase 2: Handoffs Implementation** (8-12 days)  
- **Handoff Tools**: 5-8 days - High complexity, tool-based handoff mechanism
- **Agent Registry**: 3-4 days - Medium complexity, agent lookup and management

**Phase 3: Guardrails System** (7-10 days)
- **Base Implementation**: 4-6 days - Medium-High complexity, protocol design and validation logic
- **Parallel Execution**: 3-4 days - High complexity, concurrent guardrail execution with cancellation

**Phase 4: Advanced Patterns** (12-18 days)
- **Agents-as-Tools**: 4-6 days - Medium-High complexity, recursive agent execution
- **Deterministic Workflows**: 4-6 days - Medium complexity, pipeline builder pattern  
- **LLM-as-a-Judge**: 4-6 days - Medium-High complexity, iterative improvement logic

**Integration and Testing** (8-12 days)
- **Backward Compatibility**: 3-4 days - Integration with existing GPT-Bridge
- **Comprehensive Testing**: 5-8 days - Unit and integration test coverage

### Risk Factors
- **Async/Await Complexity**: Swift concurrency differences from Python asyncio
- **Tool Integration**: Adapting Python tool patterns to Swift function calling
- **Memory Management**: Proper handling of agent context and conversation history
- **Performance Optimization**: Ensuring efficient parallel execution and context switching

## Success Metrics

### Technical Metrics
- **API Compatibility**: 100% backward compatibility with existing GPT-Bridge
- **Performance**: Agent execution latency within 10% of single assistant calls
- **Memory Usage**: Efficient context management without memory leaks
- **Test Coverage**: >90% unit test coverage for all agent components

### Developer Experience Metrics  
- **Learning Curve**: Developers can implement basic agent workflow in <30 minutes
- **Documentation Quality**: Complete examples for all major patterns
- **Error Messages**: Clear, actionable error messages for configuration issues
- **Community Adoption**: Track usage of new agent features vs. existing assistant API

## Conclusion

This plan provides a concrete roadmap for integrating proven agentic workflows from the OpenAI Agents Python SDK into GPT-Bridge. Based on direct analysis of the SDK's source code and examples, it focuses on:

1. **Exact Pattern Replication**: Implementing handoffs, guardrails, and agent loops exactly as designed in the Python SDK
2. **Swift-Native Implementation**: Leveraging Swift's type safety, concurrency, and memory management 
3. **Incremental Migration**: Allowing gradual adoption without breaking existing code
4. **Production Readiness**: Comprehensive testing, error handling, and observability

The implementation maintains GPT-Bridge's core architectural principles while adding powerful multi-agent capabilities that match the proven patterns from OpenAI's own agent framework.