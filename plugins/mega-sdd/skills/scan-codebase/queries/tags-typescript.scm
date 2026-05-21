; Tree-sitter query for TypeScript symbol extraction
; Adapted from Aider's tags.scm
; Captures: function/class/interface/type definitions and references

; Class definitions
(class_declaration
  name: (type_identifier) @name.definition.class) @definition.class

; Interface definitions
(interface_declaration
  name: (type_identifier) @name.definition.interface) @definition.interface

; Function definitions
(function_declaration
  name: (identifier) @name.definition.function) @definition.function

; Method definitions
(method_definition
  name: (property_identifier) @name.definition.method) @definition.method

; Type alias definitions
(type_alias_declaration
  name: (type_identifier) @name.definition.type) @definition.type

; Enum definitions
(enum_declaration
  name: (identifier) @name.definition.enum) @definition.enum

; Exported declarations (for public interface map)
(export_statement
  (function_declaration
    name: (identifier) @name.definition.exported.function))

(export_statement
  (class_declaration
    name: (type_identifier) @name.definition.exported.class))

; Function calls (references)
(call_expression
  function: (identifier) @name.reference.call) @reference.call

; Member expressions (method/property access)
(call_expression
  function: (member_expression
    property: (property_identifier) @name.reference.method)) @reference.method

; Type references
(type_annotation
  (type_identifier) @name.reference.type) @reference.type
