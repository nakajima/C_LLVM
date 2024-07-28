//
//  CapturesStruct.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/27/24.
//

import C_LLVM

public extension LLVM {
	struct CapturesStructType: LLVM.IRType {
		public typealias V = CapturesStruct
		let types: [any LLVM.IRType]

		public init(types: [any LLVM.IRType]) {
			self.types = types
		}

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			var types: [LLVMTypeRef?] = types.map { $0.typeRef(in: context) }
			return types.withUnsafeMutableBufferPointer {
				let ref = LLVMStructCreateNamed(context.ref, "Env")
				LLVMStructSetBody(ref, $0.baseAddress, UInt32($0.count), .zero)
				return ref!
			}
		}
	}

	struct CapturesStruct: LLVM.IRValue, LLVM.StoredPointer {
		public typealias T = CapturesStructType
		public var type: LLVM.CapturesStructType
		public var ref: LLVMValueRef

		public var offsets: [String: Int] = [:]
		public var captures: [any LLVM.StoredPointer] = []

		public init(type: LLVM.CapturesStructType, offsets: [String: Int], captures: [any LLVM.StoredPointer], ref: LLVMValueRef) {
			self.type = type
			self.offsets = offsets
			self.captures = captures
			self.ref = ref
		}

		public init(type: LLVM.CapturesStructType, ref: LLVMValueRef) {
			self.type = type
			self.ref = ref
		}

		public var isHeap: Bool {
			true
		}

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			ref
		}
		

	}
}
