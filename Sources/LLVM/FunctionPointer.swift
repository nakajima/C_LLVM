//
//  FunctionPointer.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/27/24.
//

import C_LLVM

public extension LLVM {
	public struct FunctionPointerType: IRType {
		public typealias V = FunctionPointer

		let functionType: FunctionType

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			if let captures = functionType.captures {
				StructType(name: "fnPtrWithEnv", types: [functionType, captures]).typeRef(in: context)
			} else {
				StructType(name: "fnPtr", types: [functionType]).typeRef(in: context)
			}
		}
	}

	public struct FunctionEnvironmentPointerType: IRType {
		public typealias V = CapturesStruct

		public let envStructType: StructType

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			LLVMPointerType(envStructType.typeRef(in: context), 0)
		}
	}

	public struct FunctionPointer: LLVM.StoredPointer {
		public var type: LLVM.FunctionPointerType
		
		public typealias T = FunctionPointerType
		public var ref: LLVMValueRef
		
		public var isHeap: Bool

//		var functionRef: LLVMValueRef
//		var capturesRef: LLVMValueRef?

		public init(type: LLVM.FunctionPointerType, ref: LLVMValueRef) {
			self.type = type
			self.ref = ref
			self.isHeap = type.functionType.captures != nil
		}
	}
}
