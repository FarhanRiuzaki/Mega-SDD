; Tree-sitter query for Python symbol extraction
; Adapted from Aider's tags.scm

; Class definitions
(class_definition
  name: (identifier) @name.definition.class) @definition.class

; Function definitions
(function_definition
  name: (identifier) @name.definition.function) @definition.function

; Method definitions (functions inside class — Python convention)
(class_definition
  body: (block
    (function_definition
      name: (identifier) @name.definition.method))) @definition.method

; Decorated functions / classes (captured via decorator)
(decorated_definition
  (decorator
    (call
      function: (identifier) @name.reference.decorator)))

; Function calls (references)
(call
  function: (identifier) @name.reference.call) @reference.call

; Method calls (attribute access)
(call
  function: (attribute
    attribute: (identifier) @name.reference.method)) @reference.method

; Class references in inheritance
(class_definition
  superclasses: (argument_list
    (identifier) @name.reference.class)) @reference.class

; Imports
(import_statement
  name: (dotted_name) @name.reference.module) @reference.module

(import_from_statement
  module_name: (dotted_name) @name.reference.module)
