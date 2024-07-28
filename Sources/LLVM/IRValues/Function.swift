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

		public init(type: FunctionType, captures: CapturesStruct?) {
			self.type = type
		}

		public func valueRef(in _: LLVM.Context) -> LLVMValueRef {
			fatalError("Cannot generate value ref for function, you need an EmittedValue<Function> instead.")
		}
	}

	struct EmittedFunctionValue: EmittedValue {
		public typealias V = Function

		public let type: FunctionType
		public let ref: LLVMValueRef
		public let captures: CapturesStruct?

		public init(type: FunctionType, ref: LLVMValueRef) {
			self.type = type
			self.ref = ref
			self.captures = nil
		}

		public init(type: FunctionType, ref: LLVMValueRef, captures: CapturesStruct?) {
			self.type = type
			self.ref = ref
			self.captures = captures
		}
	}
}
