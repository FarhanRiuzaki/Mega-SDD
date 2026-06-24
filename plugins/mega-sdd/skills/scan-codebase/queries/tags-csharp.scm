; Tree-sitter query for C# symbol extraction (tree-sitter-c-sharp)
; Captures: type/member definitions and references (.cs)
; Properties are captured as definitions — C# DTOs/entities model fields as
; auto-properties, so field-level binding depends on them.

; Class definitions
(class_declaration
  name: (identifier) @name.definition.class) @definition.class

; Interface definitions
(interface_declaration
  name: (identifier) @name.definition.interface) @definition.interface

; Struct definitions
(struct_declaration
  name: (identifier) @name.definition.class) @definition.class

; Enum definitions
(enum_declaration
  name: (identifier) @name.definition.enum) @definition.enum

; Record definitions
(record_declaration
  name: (identifier) @name.definition.class) @definition.class

; Method definitions
(method_declaration
  name: (identifier) @name.definition.method) @definition.method

; Constructor definitions
(constructor_declaration
  name: (identifier) @name.definition.method) @definition.method

; Property definitions (field-level surface for binding)
(property_declaration
  name: (identifier) @name.definition.field) @definition.field

; Object instantiation (references)
(object_creation_expression
  type: (identifier) @name.reference.class) @reference.class

; Method calls (references)
(invocation_expression
  function: (member_access_expression
    name: (identifier) @name.reference.call)) @reference.call
