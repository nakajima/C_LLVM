//
//  Function+Environment.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM.Function {
	class Environment {
		public enum Binding {
			// A `defined` binding means the the variable was defined in the current
			// function scope. It can just be on the stack and used normally.
			case defined(any LLVM.StoredPointer)

			// A `parameter` binding is part of the function's parameters. These get
			// set in Builder.define.
			case parameter(any LLVM.EmittedValue)

			// A `capture` binding is used by nested scopes. The Int value is the index
			// of the capture in the additional arguments passed to the function at call
			// time.
			case capture(Int, any LLVM.IRType)
		}

		// We store a builder and the environment's function ref so we can
		// go back and malloc captured values we find while handling closures
		// They're optional because there's a weird dependency relationship
		// here between functions and their environments and their functions
		// that I'd like to make more one way.
		var builder: LLVM.Builder?
		var functionRef: LLVMValueRef?

		// Storing a parent lets us lookup in parent environments to see if
		// a value is there (using .uplook). If we find one, we can use the
		// buidler/functionRef to handle capturing those values and update the
		// parent to look at the captured value instead of its original param
		// or stack value.
		var parent: Environment?

		// This is where variable bindings actually live.
		var bindings: [String: Binding] = [:]

		// When an environment has one of its bindings captured by a child, we
		// allocate it onto the stack and add that to this array. At function calls,
		// we walk the current environment + parents, adding captures as arguments
		// to the called function. Its environment knows to find these values as
		// arguments because they are designated as Binding.capture values.
		var captures: [any LLVM.StoredPointer] = []

		public let name: String

		public init(builder: LLVM.Builder? = nil, name: String, parent: Environment? = nil) {
			self.builder = builder
			self.name = name
			self.parent = parent
		}

		public func get(_ name: String) -> Binding? {
			// If it's in the current environment, we're good to go
			if let binding = bindings[name] {
				return binding
			}

			// If it's not, then we need to emit capture code for this one
			if let binding = parent?.uplook(name) {
				return binding
			}

			return nil
		}

		var captureList: [any LLVM.StoredPointer] {
			var result: [any LLVM.StoredPointer] = []

//			if let parent {
//				result.append(contentsOf: parent.captureList)
//			}

			result.append(contentsOf: captures)

			return result
		}

		var currentCaptureIndex: Int {
			(parent?.currentCaptureIndex ?? 0) + captures.count
		}

		func uplook(_ name: String) -> Binding? {
			switch bindings[name] {
			case let .defined(pointer):
				let heapValue = builder!.capture(pointer, name: name, in: functionRef!)
				captures.append(heapValue)
				return .capture(currentCaptureIndex, pointer.type)
			case let .parameter(value):
				let heapValue = builder!.capture(value, name: name, in: functionRef!)
				captures.append(heapValue)
				return .capture(currentCaptureIndex, value.type)
			case .capture(_):
				return bindings[name]!
			default:
				return nil
			}

			return parent?.uplook(name)
		}

		public func type(of name: String) -> (any LLVM.IRType)? {
			guard case let .defined(pointer) = bindings[name] else {
				return nil
			}

			return pointer.type
		}

		public func parameter(_ name: String, as value: any LLVM.EmittedValue) {
			bindings[name] = .parameter(value)
		}

		public func define(_ name: String, as value: any LLVM.StoredPointer) {
			bindings[name] = .defined(value)
		}
	}
}
