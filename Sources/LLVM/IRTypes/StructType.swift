//
//  StructType.swift
//  LLVM
//
//  Created by Pat Nakajima on 7/30/24.
//
import C_LLVM

public extension LLVM {
	struct StructType: LLVM.IRType {
		public typealias V = StructInstanceValue
		let name: String
		let types: [any LLVM.IRType]
		let namedTypeRef: LLVMTypeRef?

		public init(name: String, types: [any LLVM.IRType], namedTypeRef: LLVMTypeRef?) {
			self.name = name
			self.types = types
			self.namedTypeRef = namedTypeRef
		}

		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			if let namedTypeRef {
				return namedTypeRef
			}

			var types: [LLVMTypeRef?] = types.map { $0.typeRef(in: context) }
			return types.withUnsafeMutableBufferPointer {
				let ref = LLVMStructCreateNamed(context.ref, name)
				LLVMStructSetBody(ref, $0.baseAddress, UInt32($0.count), .zero)
				return ref!
			}
		}

		public func pointer(in context: LLVM.Context) -> any StoredPointer {
			HeapValue(type: self, ref: typeRef(in: context))
		}

		public func emit(ref: LLVMValueRef) -> any LLVM.EmittedValue {
			EmittedStructPointerValue(type: self, ref: ref)
		}
	}

	struct StructInstanceValue: LLVM.IRValue {
		public var type: LLVM.StructType
	}
}
