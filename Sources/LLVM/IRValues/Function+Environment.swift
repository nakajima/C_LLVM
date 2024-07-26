//
//  Function+Environment.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

public extension LLVM.Function {
	public struct Environment {
		public enum Binding {
			case defined(any LLVM.StoredPointer), parameter(Int)
		}

		var bindings: [String: Binding] = [:]

		public init() {}

		public func get(_ name: String) -> Binding? {
			bindings[name]
		}

		public mutating func parameter(_ name: String, at index: Int) {
			bindings[name] = .parameter(index)
		}

		public mutating func define(_ name: String, as value: any LLVM.StoredPointer) {
			bindings[name] = .defined(value)
		}
	}
}
