; Tree-sitter query for PHP symbol extraction
; Adapted from Aider's tags.scm

; Class definitions
(class_declaration
  name: (name) @name.definition.class) @definition.class

; Interface definitions
(interface_declaration
  name: (name) @name.definition.interface) @definition.interface

; Trait definitions
(trait_declaration
  name: (name) @name.definition.trait) @definition.trait

; Method definitions (within class)
(method_declaration
  name: (name) @name.definition.method) @definition.method

; Function definitions
(function_definition
  name: (name) @name.definition.function) @definition.function

; Property definitions
(property_declaration
  (property_element
    (variable_name) @name.definition.property)) @definition.property

; Function calls (references)
(function_call_expression
  function: (name) @name.reference.call) @reference.call

; Method calls (references)
(member_call_expression
  name: (name) @name.reference.method) @reference.method

; Static method calls
(scoped_call_expression
  name: (name) @name.reference.static_method) @reference.static_method

; Class instantiations
(object_creation_expression
  (name) @name.reference.class) @reference.class

; Use statements (imports)
(namespace_use_declaration
  (namespace_use_clause
    (qualified_name) @name.reference.namespace)) @reference.namespace
