## TODOs

- Complete the reader
- Add tests

### Less emergent

- Explicit error types & error details in `Gardener` and `Reader`
- Lisp exception system
- Garbage collection
  - Currently, `Gardener` simply frees everything at `deinit()`

## Style guide

### Structs

If something has no inner state, don't make it a struct.

### Constness of `LispObject`s

In general, `LispObject`s are passed around via `*LispObject` pointers.

- For parameters, prefer `*const LispObject`
  - Prevents accidental mutation
  - When necessary, use `*LispObject` instead, e.g.:
    - To mutate the object
    - The object itself will be passed somewhere else, e.g., stored in the `car`/`cdr` field of another object
- For return values, prefer `*LispObject`
  - This allows the returned pointer to be used anywhere, in both const and non-const contexts
  - When necessary, use `*const LispObject` instead
    - Although I haven't come up with any such scenario

The only allowed mutation on a `LispObject` is modifying the `car`/`cdr`, given that this object is a pair. **NEVER** mutate any other type of object (`nil`, `boolean`, `integer`, `symbol`, etc.).
