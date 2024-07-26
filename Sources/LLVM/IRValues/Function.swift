//
//  Function.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
	struct Function: IRValue {
		public typealias T = FunctionType
		
		public let type: FunctionType
		public let environment: Environment

		public init(type: FunctionType, environment: Environment) {
			self.type = type
			self.environment = environment
		}

		public func valueRef(in context: LLVM.Context) -> LLVMValueRef {
			fatalError("Cannot generate value ref for function, you need an EmittedValue<Function> instead.")
		}
	}

	struct EmittedFunctionValue: EmittedValue {
		public let type: FunctionType
		public let value: Function
		public let ref: LLVMValueRef

		public init(type: FunctionType, value: Function, ref: LLVMValueRef) {
			self.type = type
			self.value = value
			self.ref = ref
		}
	}
}
