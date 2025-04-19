# frozen_string_literal: true

class TypedStruct
  class << self
    def zero_values
      {
        int: 0,
        string: '',
        any: nil
      }.freeze
    end

    def typed_struct_type?(t)
      return false unless t.respond_to? :superclass
      return false unless t.superclass == TypedStruct

      true
    end

    def __attributes
      @__attributes ||= {}
    end
  end

  def self.define(name, type)
    is_typed_struct = false
    is_typed_struct = type.superclass == TypedStruct if type.respond_to? :superclass

    raise ArgumentError, "unsupported type #{type}" unless zero_values.key?(type) || is_typed_struct

    __attributes[name] = type

    attr_reader name

    # safe_assign と異なり、= で代入したときは型チェックに失敗したら例外を投げる
    define_method "#{name}=" do |v|
      assign! name, v
    end
  end

  def initialize(init = {})
    defined_attributes = self.class.__attributes

    defined_attributes.each do |name, type|
      zero = self.class.zero_values[type]
      value = init.fetch name, zero
      assign! name, value
    end
  end

  # 代入時に型チェックをし、成功したら true、失敗したら false を返す
  def safe_assign(to, value)
    t = self.class.__attributes[to]
    return false if t.nil?

    valid = false
    # プリミティブな型のチェック
    case t
    when :int
      valid = value.is_a? Integer
    when :string
      valid = value.is_a? String
    when :any
      valid = true
    end
    # TypedStruct のチェック
    valid = value.is_a? t if self.class.typed_struct_type? t

    return false unless valid

    instance_variable_set "@#{to}", value

    true
  end

  private

  def assign!(to, value)
    ok = safe_assign to, value
    return if ok

    raise TypeError, "cannot assign #{value} to #{self.class}.#{to}"
  end
end
