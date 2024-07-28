//
//  IntType.swift
//  C_LLVM
//
//  Created by Pat Nakajima on 7/25/24.
//

import C_LLVM

public extension LLVM {
    struct IntType: IRType, IR {
        public typealias V = IntValue

        let width: Int

        init(width: Int) {
            self.width = width
        }

        public func typeRef(in context: LLVM.Context) -> LLVMTypeRef {
            LLVMIntTypeInContext(context.ref, UInt32(width))
        }

        public func constant(_ value: Int) -> Constant<IntValue, Int> {
            Constant(type: .i32, value: IntValue(type: .i32), literal: value)
        }
    }
}

// MARK: Convenience

public extension LLVM.IRType where Self == LLVM.IntType {
    static var i1: LLVM.IntType {
        LLVM.IntType(width: 1)
    }

    static var i8: LLVM.IntType {
        LLVM.IntType(width: 8)
    }

    static var i16: LLVM.IntType {
        LLVM.IntType(width: 16)
    }

    static var i32: LLVM.IntType {
        LLVM.IntType(width: 32)
    }

    static var i64: LLVM.IntType {
        LLVM.IntType(width: 64)
    }
}