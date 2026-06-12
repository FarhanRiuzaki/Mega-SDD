; Tree-sitter query for Rust symbol extraction
; Adapted from Aider's tags.scm
; Captures: fn/struct/enum/trait/impl definitions and references (.rs)
; Visibility (pub vs private) is resolved by the scan from the node's source line.

; Function definitions
(function_item
  name: (identifier) @name.definition.function) @definition.function

; Struct definitions
(struct_item
  name: (type_identifier) @name.definition.class) @definition.class

; Enum definitions
(enum_item
  name: (type_identifier) @name.definition.enum) @definition.enum

; Trait definitions
(trait_item
  name: (type_identifier) @name.definition.interface) @definition.interface

; Impl blocks (methods attach to the implemented type)
(impl_item
  type: (type_identifier) @name.reference.implementation) @reference.implementation

; Module definitions
(mod_item
  name: (identifier) @name.definition.module) @definition.module

; Macro definitions
(macro_definition
  name: (identifier) @name.definition.macro) @definition.macro

; Function calls (references)
(call_expression
  function: (identifier) @name.reference.call) @reference.call

; Method / associated-function calls (references)
(call_expression
  function: (field_expression
    field: (field_identifier) @name.reference.method)) @reference.method

(call_expression
  function: (scoped_identifier
    name: (identifier) @name.reference.call)) @reference.call

; Type references
(type_identifier) @name.reference.type
