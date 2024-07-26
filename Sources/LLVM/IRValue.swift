//
//  IRValue.swift
//
//
//  Created by Pat Nakajima on 7/16/24.
//
import C_LLVM

public extension LLVM {
	protocol IRValue: IR {
		associatedtype T: IRType

		var type: T { get }
	}

	struct RawValueType: IRType {
		public typealias V = RawValue
		
		public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
			fatalError()
		}
	}

	struct RawValue: IRValue {
		public let type = RawValueType()
		public let ref: LLVMValueRef
	}
}

extension LLVM.IRValue where Self == LLVM.RawValue {
	public static func raw(_ ref: LLVMValueRef) -> LLVM.RawValue {
		LLVM.RawValue(ref: ref)
	}
}

public extension LLVM.IRValue {
	var isPointer: Bool {
		false
	}
}
