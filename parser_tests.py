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
>>> 4.8
4.8

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
3.0
>>> 4 % 3
1
>>> 1+2*3
7
>>> (1+2)*3
9
>>> 3==3
True
>>> 3!=3
False
>>> 3 & 2
2
>>> 1 | 2
3
>>> ~0
-1
>>> ~5
-6
>>> ~-6
5

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
>>> a = 0
... while True:
...     a = a + 1
...     if a == 1: continue
...     break
... a
2

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
>>> s = 0
... for i in 1, 2, 3:
...     s = 1
...     continue
...     s = 2
... s
1

# complex if
>>> a=1
>>> if a == 0:
...     a = a + 1
... elif a == 1:
...     a = a + 3
... else:
...     a = a + 5
>>> a
4
>>> a = 3; a = (1 if a > 2 else 4); a
1

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
>>> "\n"
'\n'
>>> ''
''
>>> a = "abc"
>>> len(a)
3
>>> 'abc'[0]
'a'
>>> ''[-2]
IndexError: index out of range
>>> 'abc'[1:]
'bc'
>>> 'abc'[:-2]
'a'

# lists
>>> []
[]
>>> a = [1, [2], 3]; a[1:], a[:1]
([[2], 3], [1])
>>> len([]), len([1])
(0, 1)

# tuples
>>> ()
()
>>> a = (1, (2,), 3); a[2:], a[:2]
((3,), (1, (2,)))
>>> len(()), len((3,)), len(((), ()))
(0, 1, 2)

# dicts
>>> {}
{}
>>> a = {'a': 3, 'b': 4}
>>> len(a), a['a'], a['b'], a['c']
(2, 3, 4, None)

# sets
>>> {1}
{1}
>>> {1,2,2,1}
{1, 2}

# in
>>> 3 in [1, 2, 3], 3 not in [1, 2]
UnimplementedError
>>> 3 in (1, 2, 3), 3 not in (1, 2)
UnimplementedError
>>> 3 in {1, 2, 3}, 3 not in {1, 2}
UnimplementedError
>>> 3 in {1: '1', 2: '2', 3: '3'}, 3 not in {1: 1, 2: 2}
UnimplementedError

# complex for
>>> kk, vv = 0, 0
>>> for k,v in {3: 1, 4: 2}:
...     kk = kk + k
...     vv = vv + v
>>> (kk, vv)
(7, 3)

# logic
>>> False and False
False
>>> True and False
False
>>> False and True
False
>>> True and True
True
>>> False or False
False
>>> True or False
True
>>> False or True
True
>>> True or True
True
>>> not True, not False
(False, True)
>>> not not True
True

# exceptions
>>> a = 0
>>> try:
...     raise
...     a = 4
... except:
...     a = 1
... else:
...     a = a + 1
>>> a
1
>>> a = 0
>>> try:
...     try:
...         raise
...         a = 4
...     finally:
...         a = 1
... except:
...     a = a + 1
>>> a
2
>>> a = 0
>>> try:
...     a = 4
... except:
...     a = 1
... else:
...     a = a + 1
>>> a
5
>>> a = 0
... try:
...     raise 2
... except 1:
...     a = 1
... except 2 as b:
...     a = b
... a
2

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

# get/set/del
>>> a = {1: 2}
>>> b = len(a)
>>> del(a, 1)
>>> b, len(a)
(1, 0)

# factorial
>>> def fac(n):
...     if n == 0:
...         return 1
...     return n * fac(n - 1)
>>> fac(11)
39916800

# fibonacci
>>> def fib(n):
...     if n <= 2: return 1
...     return fib(n - 1) + fib(n - 2)
>>> fib(20)
6765

# syntax errors
>>> if 1
SyntaxError: expected : but found NEWLINE at line 1
>>> break 1
SyntaxError: expected NEWLINE but found 1 at line 1
>>> class "A"
SyntaxError: expected NAME but found "A" at line 1
>>> global a, b,
SyntaxError: expected NAME but found NEWLINE at line 1
>>> a = 
SyntaxError: expected (, [, {, NAME, NUMBER, or STRING but found NEWLINE at line 1

# no INDENT/DEDENT/NEWLINE inside of parentheses
>>> a = [1,
...      2]
... a
[1, 2]
>>> a = {
...     1: 2,
... }
{1: 2}

# assert
>>> assert True
>>> assert True, "message"
>>> assert False
AssertionError
>>> assert False, "message"
AssertionError: message

# augmented assigns
>>> a, b, c, d = 1, 2, 4, 8
... a += 5
... b -= 5
... c *= 3
... d /= 2
... (a, b, c, d)
(6, -3, 12, 4.0)
>>> a = 17; a %= 7; a
3
>>> a = 192; a &= 224; a |= 130; a
194

# imports
>>> import a
ModuleNotFoundError: No module named 'a'
>>> import a as x
ModuleNotFoundError: No module named 'a'
>>> import a, b,
ModuleNotFoundError: No module named 'a'
>>> import a, b as x
ModuleNotFoundError: No module named 'a'
>>> from a import *
ModuleNotFoundError: No module named 'a'
>>> from a import a
ModuleNotFoundError: No module named 'a'
>>> from a import a, b as x, c,
ModuleNotFoundError: No module named 'a'

# complex comparison
>>> 1 < 4 < 5
True
>>> 1 < 1 < 5, 1 < 5 < 5
(False, False)
>>> 4 >= 3
True

# global
>>> x = 1
... def f(x):
...     global x
...     return x
... f(2)
UnimplementedError
