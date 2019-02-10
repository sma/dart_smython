# simple tests
>>> 1
1
>>> a=1
>>> a
1
>>> a=1
>>> b=2
>>> a+b
3

# arthmetic
>>> 1+3
4
>>> 5-4
1
>>> -5
-5
>>> 2*3
6
>>> 9/3
3
>>> 1+2*3
7
>>> (1+2)*3
9
>>> 3==3
True
>>> 3!=3
False

# parallel assignment
>>> a, b = 2, 3
>>> a, b
(2, 3)
>>> a, b = 2, 3
>>> a, b = b, a
>>> a, b
(3, 2)
>>> a = 1, 2
>>> a, (b, c) = 0, a
>>> a, b, c
(0, 1, 2)

# while loop
>>> a = 0
>>> while a < 3:
...     a = a + 1
... else:
...     b = 1
>>> a, b
(3, 1)
>>> a = 0
>>> while a < 3:
...     a = a + 1
...     if a == 1: break
... else:
...     a = 0
>>> a
1

# for loop
>>> s = 0
>>> for i in 1, 2, 3:
...     s = s + i
... else:
...     s = -s
>>> s
-6
>>> s = 0
>>> for i in 1, 2, 3:
...     s = s + i
...     if i == 2:
...         break
... else: s = 0
>>> s
3

# constants
>>> True, False, None
(True, False, None)

# function
>>> def f(): return 1
>>> f()
1
>>> def f(n): return n+1
>>> f(2)
3

# function with default parameters
>>> def f(x=2): return x
>>> f()
2
>>> def f(x=2): return x
>>> f(3)
3

# strings
>>> "Hallo, Welt"
'Hallo, Welt'
>>> "'" '"'
'\'"'
>>> a = "abc"
>>> len(a)
3
>>> 'abc'[0]
'a'
>>> ''[-2]
IndexError: index out of range
>>> 'abc'[1:]
'bc'

# lists
>>> []
[]
>>> [1, [2], 3][1:]
[[2], 3]
>>> len([]), len([1])
(0, 1)

# tuples
>>> ()
()
>>> (1, (2,), 3)[2:]
(3,)
>>> len(()), len((3,)), len(((), ()))
(0, 1, 2)

# dicts
>>> {}
{}
>>> a = {'a': 3, 'b': 4}
>>> len(a), a['a'], a['b'], a['c']
(2, 3, 4, None)

# classes & instances
>>> class A:
...     def m(self): return 1
>>> class B(A):
...     def n(self):
...         return 2
>>> a, b = A(), B()
>>> a.m(), b.m(), b.n()
(1, 1, 2)
>>> class A: pass
>>> class B (A): pass
>>> A, B.__superclass__, B.__superclass__.__superclass__
(<class 'A'>, <class 'A'>, None)
>>> class C:
...     def __init__(self, x): self.x = x
...     def m(self): return self.x + 1
>>> c = C(7)
>>> c.x, c.m()
(7, 8)
