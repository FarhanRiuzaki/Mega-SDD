; Tree-sitter query for Go symbol extraction
; Adapted from Aider's tags.scm
; Captures: function/method/type definitions and references (.go)

; Function definitions
(function_declaration
  name: (identifier) @name.definition.function) @definition.function

; Method definitions (receiver functions)
(method_declaration
  name: (field_identifier) @name.definition.method) @definition.method

; Type definitions (struct / interface / alias targets)
(type_declaration
  (type_spec
    name: (type_identifier) @name.definition.type)) @definition.type

; Interface method specs (public interface surface)
(method_elem
  name: (field_identifier) @name.definition.interface_method) @definition.interface_method

; Package-level constants and variables
(const_declaration
  (const_spec
    name: (identifier) @name.definition.constant)) @definition.constant

; Function calls (references)
(call_expression
  function: (identifier) @name.reference.call) @reference.call

; Selector calls (pkg.Func / receiver.Method references)
(call_expression
  function: (selector_expression
    field: (field_identifier) @name.reference.method)) @reference.method

; Type references in declarations
(type_identifier) @name.reference.type
