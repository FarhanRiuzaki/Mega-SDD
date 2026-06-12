; Tree-sitter query for Java symbol extraction
; Adapted from Aider's tags.scm
; Captures: class/interface/enum/method definitions and references (.java)

; Class definitions
(class_declaration
  name: (identifier) @name.definition.class) @definition.class

; Interface definitions
(interface_declaration
  name: (identifier) @name.definition.interface) @definition.interface

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

; Method calls (references)
(method_invocation
  name: (identifier) @name.reference.call) @reference.call

; Object instantiation (references)
(object_creation_expression
  type: (type_identifier) @name.reference.class) @reference.class

; Type references
(type_identifier) @name.reference.type
