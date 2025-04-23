# frozen_string_literal: true

require 'json'

module Typed
  module Internal
    def self.zero_value(typedef)
      primitives = {
        Integer => 0,
        String => '',
        Float => 0.0,
        Boolean::BooleanClass => false,
        Object => nil
      }

      return primitives[typedef] if primitive_class_typedef? typedef
      return primitives[primitive_typedef_classes[typedef]] if primitive_typedef? typedef

      return typedef.new if typed_struct_typedef? typedef

      return [] if array_typedef? typedef

      raise TypeError, "typedef #{typedef.inspect} is not supported"
    end

    def self.primitive_typedef_classes
      {
        int: Integer,
        string: String,
        float: Float,
        bool: Boolean::BooleanClass,
        any: Object
      }
    end

    def self.as_class_typedef(typedef)
      return primitive_typedef_classes[typedef] if primitive_typedef?(typedef)
      return [as_class_typedef(typedef[0])] if array_typedef?(typedef)

      typedef
    end

    def self.primitive_class_typedef?(typedef)
      primitive_typedef_classes.value? typedef
    end

    def self.primitive_typedef?(typedef)
      primitive_typedef_classes.key? typedef
    end

    def self.typed_struct_typedef?(typedef)
      return false unless typedef.respond_to? :superclass
      return false unless typedef.superclass == TypedStruct

      true
    end

    def self.array_typedef?(typedef)
      return false unless typedef.is_a? Array
      return false unless typedef.length == 1
      return false unless supported_type?(typedef[0])

      true
    end

    def self.supported_type?(typedef)
      return true if primitive_typedef?(typedef)
      return true if primitive_class_typedef?(typedef)
      return true if array_typedef?(typedef)
      return true if typed_struct_typedef?(typedef)

      false
    end

    def self.type_correct?(typedef, v)
      raise TypeError, 'ここでシンボルの型定義は登場しないはず' if primitive_typedef?(typedef)

      # :any 以外は nil を許容しない
      return false if typedef != Object && v.nil?

      if primitive_class_typedef?(typedef)
        return true if typedef == Object
        return true if typedef == Boolean::BooleanClass && Boolean.bool?(v)

        return v.is_a?(typedef)
      end

      return v.is_a?(typedef) if typed_struct_typedef? typedef

      return v.all? { |el| type_correct?(typedef[0], el) } if array_typedef? typedef

      raise ArgumentError, "typedef #{typedef.inspect} is not supported"
    end

    module Boolean
      def self.bool?(v)
        [true, false].include? v
      end

      # TrueClass と False クラスを透過的に扱えるようにするためのクラス。
      # true.is_a? BooleanClass は当然ながら偽なので、その判定は個別に書く必要がある。
      class BooleanClass
        def self.deserialize(hash)
          hash
        end
      end
    end

    module SerializableArray
      refine Array.singleton_class do
        def deserialize_elements(hash, element_class)
          hash.map do |v|
            if element_class.respond_to? :deserialize
              element_class.deserialize v
            elsif element_class.respond_to? :deserialize_elements
              element_class.deserialize_elements v, element_class[0]
            else
              v
            end
          end
        end
      end

      refine Array do
        def serialize
          map do |v|
            if v.respond_to? :serialize
              v.serialize
            else
              v
            end
          end
        end

        def deserialize_elements(hash, object_class)
          Array.deserialize_elements hash, object_class
        end
      end
    end

    RubyJSON = JSON
  end
end

class TypedStruct
  using Typed::Internal::SerializableArray

  class << self
    def define(name, typedef, tags = {})
      unless Typed::Internal.supported_type?(typedef)
        raise ArgumentError,
              "typedef #{typedef.inspect} is not supported"
      end

      __attributes[name] = Typed::Internal.as_class_typedef typedef

      attr_reader name

      define_method "#{name}=" do |v|
        assign! name, v
      end
    end

    def deserialize(hash)
      # この構造体が nil 許容かどうかはここでは気にしない。後でインスタンス化する際に型チェックされるため。
      return nil if hash.nil?

      hash.each_key do |key|
        typedef = __attributes[key]

        hash[key] = typedef.deserialize hash[key] if typedef.respond_to? :deserialize
        hash[key] = typedef.deserialize_elements hash[key], typedef[0] if typedef.respond_to? :deserialize_elements
      end

      new(hash)
    end

    def __attributes
      @__attributes ||= {}
    end
  end

  # インスタンス化時に初期値を指定する場合、{ [key] => value } 形式で渡す
  def initialize(init = {})
    self.class.__attributes.each do |name, typedef|
      zero = Typed::Internal.zero_value typedef
      value = init.fetch name, zero
      assign! name, value
    end
  end

  def []=(key, value)
    assign! key.to_sym, value
  end

  def [](key)
    instance_variable_get "@#{key}"
  end

  def serialize
    hash = {}
    self.class.__attributes.each_key do |name|
      v = instance_variable_get "@#{name}"
      v = v.serialize if v.respond_to? :serialize

      hash[name] = v
    end
    hash
  end

  private

  def assign!(to, value)
    ok = safe_assign to, value
    return if ok

    raise TypeError, "cannot assign #{value.inspect} to #{self.class}.#{to}"
  end

  def safe_assign(to, value)
    typedef = self.class.__attributes[to]
    return false unless Typed::Internal.type_correct?(typedef, value)

    instance_variable_set "@#{to}", value
    true
  end
end

module TypedSerialize
  using Typed::Internal::SerializableArray

  module JSON
    # JSON 文字列に変換する。
    # オブジェクトが serialize() -> Hash メソッドを持つ場合、そのメソッドの返り値 (Hash) を利用する。
    def marshal(v)
      h = v.serialize
      Typed::Internal::RubyJSON.generate h
    end

    # JSON 文字列から typedef で指定した型に変換する。
    # オブジェクトが self.deserialize(Hash) -> T あるいは self.deserialize_elements(Hash, U) -> T<U> のいずれかのメソッドを持つ場合、その結果を使って変換する。
    def unmarshal(data, typedef)
      h = Typed::Internal::RubyJSON.parse data, symbolize_names: true

      if typedef.respond_to? :deserialize_elements
        typedef.deserialize_elements h, typedef[0]
      elsif typedef.respond_to? :deserialize
        typedef.deserialize h
      else
        h
      end
    end

    module_function :marshal, :unmarshal
  end
end
