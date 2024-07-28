//
//  Function+Environment.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

public extension LLVM.Function {
	class Environment {
		public enum Binding {
			case declared(any LLVM.StoredPointer), defined(any LLVM.StoredPointer), parameter(Int), function(String)
		}

		var parent: Environment?
		var bindings: [String: Binding] = [:]

		public init(parent: Environment? = nil) {
			self.parent = parent
		}

		public func get(_ name: String) -> Binding? {
			// If it's in the current environment, we're good to go
			if let binding = bindings[name] {
				return binding
			}

			// If it's not, then we can't return params anymore
			if let binding = parent?.bindings[name] {
				return binding
			}

			return nil
		}

		public func type(of name: String) -> (any LLVM.IRType)? {
			guard case let .defined(pointer) = bindings[name] else {
				return nil
			}

			return pointer.type
		}

		public func parameter(_ name: String, at index: Int) {
			bindings[name] = .parameter(index)
		}

		public func define(_ name: String, as value: any LLVM.StoredPointer) {
			bindings[name] = .defined(value)
		}

		public func declare(_ name: String, as value: any LLVM.StoredPointer) {
			bindings[name] = .declared(value)
		}

		public func declareFunction(_ name: String) {
			bindings[name] = .function(name)
		}
	}
}
