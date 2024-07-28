//
//  CapturesStruct.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/27/24.
//

import C_LLVM

public extension LLVM {
	struct StructType: LLVM.IRType {
		public typealias V = CapturesStruct
		let name: String
		let types: [any LLVM.IRType]

		public init(name: String, types: [any LLVM.IRType]) {
			self.name = name
			self.types = types
		}

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			var types: [LLVMTypeRef?] = types.map { LLVMPointerType($0.typeRef(in: context), 0) }
			return types.withUnsafeMutableBufferPointer {
				let ref = LLVMStructCreateNamed(context.ref, name)
				LLVMStructSetBody(ref, $0.baseAddress, UInt32($0.count), .zero)
				return ref!
			}
		}

		public func pointer(in context: LLVM.Context) -> any StoredPointer {
			HeapValue(type: self, ref: typeRef(in: context))
		}
	}

//	struct StructValue: LLVM.IRValue, LLVM.StoredPointer {
//		public typealias T = StructType
//		public var type: LLVM.StructType
//		public var ref: LLVMValueRef
//		public let isHeap = true
//
//		static func create(name: String, from values: [any StoredPointer], with builder: Builder) -> StructValue {
//			let structType = StructType(name: name, types: values.map(\.type))
//			let structTypeRef = structType.typeRef(in: builder.context)
//			let pointer = builder.malloca(type: structType, name: name)
//
//			for (i, value) in values.enumerated() {
//				print("-> setting gep for \(Swift.type(of: value))")
//				let field = LLVMBuildStructGEP2(builder.builder, structTypeRef, pointer.ref, UInt32(i), "")
//				LLVMBuildStore(builder.builder, value.ref, field)
//			}
//
//			return StructValue(type: structType, ref: pointer.ref)
//		}
//
//		public init(type: LLVM.StructType, ref: LLVMValueRef) {
//			self.type = type
//			self.ref = ref
//		}
//	}

	struct CapturesStruct: LLVM.IRValue, LLVM.StoredPointer {
		public typealias T = StructType
		public var type: LLVM.StructType
		public var ref: LLVMValueRef

		public var offsets: [String: Int] = [:]
		public var captures: [any LLVM.StoredPointer] = []

		public init(type: LLVM.StructType, offsets: [String: Int], captures: [any LLVM.StoredPointer], ref: LLVMValueRef) {
			self.type = type
			self.offsets = offsets
			self.captures = captures
			self.ref = ref
		}

		public init(type: LLVM.StructType, ref: LLVMValueRef) {
			self.type = type
			self.ref = ref
		}

		public var isHeap: Bool {
			true
		}

		public func typeRef(in _: LLVM.Context) -> LLVMTypeRef {
			ref
		}
	}
}
