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

		public func valueRef(in _: LLVM.Context) -> LLVMValueRef {
			fatalError("Cannot generate value ref for function, you need an EmittedValue<Function> instead.")
		}
	}

	struct EmittedFunctionValue: EmittedValue {
		public init(type: LLVM.FunctionType, ref: LLVMValueRef) {
			self.type = type
			self.ref = ref
		}
		
		public typealias V = Function

		public let type: FunctionType

		// The ref of an emitted function value points to a two item struct.
		// The first item is the function ref itself, the second is to the
		// environment, which contains the captures for the function.
		public let ref: LLVMValueRef
	}
}
