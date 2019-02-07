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

# function
>>> def f(): return 1
>>> f()
1
>>> def f(n): return n+1
>>> f(2)
3

# constants
>>> True
1
>>> False
0
>>> None
None

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
