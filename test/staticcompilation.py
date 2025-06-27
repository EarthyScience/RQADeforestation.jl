import ctypes as ct
import numpy as np

class MallocVector(ct.Structure):
    _fields_ = [("pointer", ct.c_void_p),
                ("length", ct.c_int64),
                ("s1", ct.c_int64)]

class MallocMatrix(ct.Structure):
    _fields_ = [("pointer", ct.c_void_p),
                ("length", ct.c_int64),
                ("s1", ct.c_int64),
                ("s2", ct.c_int64)]

def mvptr(A):
    ptr = A.ctypes.data_as(ct.c_void_p)
    a = MallocVector(ptr, ct.c_int64(A.size), ct.c_int64(A.shape[0]))
    return ct.byref(a)

def mmptr(A):
    ptr = A.ctypes.data_as(ct.c_void_p)
    a = MallocMatrix(ptr, ct.c_int64(A.size), ct.c_int64(A.shape[1]), ct.c_int64(A.shape[0]))
    return ct.byref(a)

lib = ct.CDLL("./libmul.dylib")

A = np.ones((10,10))
B = np.ones((10,10))
C = np.ones((10,10))

Aptr = mmptr(A)
Bptr = mmptr(B)
Cptr = mmptr(C)

lib.julia_mul_inplace(Cptr, Bptr, Aptr)