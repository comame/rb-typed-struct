# frozen_string_literal: true

require 'json'
require 'yaml'

module Typed
  module Internal
    def self.initial_value(typedef, allow_nil)
      # nil許容だったら、初期値は nil
      return nil if allow_nil

      primitives = {
        Integer => 0,
        String => '',
        Float => 0.0,
        Boolean::BooleanClass => false,
        Symbol => ''.to_sym,
        Object => nil
      }

      return primitives[typedef] if primitive_class_typedef? typedef
      return primitives[primitive_typedef_classes[typedef]] if primitive_typedef? typedef

      return typedef.new if typed_struct_typedef? typedef

      return [] if array_typedef? typedef

      raise TypeError, "typedef #{typedef.inspect} is not supported"
    end

    def self.zero_value?(value, typedef)
      return true if value.nil?

      return true if primitive_class_typedef?(typedef) && initial_value(typedef, false) == value
      return true if array_typedef?(typedef) && value.empty?

      return false if typed_struct_typedef?(typedef)

      false
    end

    def self.primitive_typedef_classes
      {
        int: Integer,
        string: String,
        float: Float,
        bool: Boolean::BooleanClass,
        any: Object,
        symbol: Symbol
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

    def self.type_correct?(typedef, v, allow_nil)
      raise TypeError, 'ここでシンボルの型定義は登場しないはず' if primitive_typedef?(typedef)

      if allow_nil
        return true if v.nil?
      elsif typedef != Object && v.nil?
        # :any 以外は nil を許容しない
        return false
      end

      if primitive_class_typedef?(typedef)
        return true if typedef == Object
        return true if typedef == Boolean::BooleanClass && Boolean.bool?(v)

        return v.is_a?(typedef)
      end

      return v.is_a?(typedef) if typed_struct_typedef? typedef

      # 配列型の要素は nil 許容にさせない。
      # うまい typedef の表記を思いつかないし、そもそも配列の中に nil を混ぜる設計自体があまりよくないので。
      # どうしても必要なら [:any] で表現してほしい。
      return v.all? { |el| type_correct?(typedef[0], el, false) } if array_typedef? typedef

      raise ArgumentError, "typedef #{typedef.inspect} is not supported"
    end

    module Boolean
      def self.bool?(v)
        [true, false].include? v
      end

      # TrueClass と FalseClass を透過的に扱えるようにするためのクラス。
      # true.is_a? BooleanClass は当然ながら偽なので、その判定は個別に書く必要がある。
      class BooleanClass
        def self.deserialize(hash)
          hash
        end
      end
    end

    module JSONTag
      def self.json_key_or_nil(tag_hash)
        key = (tag_hash.fetch :json, '').split(',').first

        return nil if key.nil?
        return nil if key == ''

        key
      end

      def self.omit_empty?(tag_hash)
        opt = (tag_hash.fetch :json, '').split(',')[1]

        opt == 'omitempty'
      end

      def self.should_skip?(tag_hash)
        tag_value = tag_hash.fetch :json, ''
        tag_value == '-'
      end
    end

    module SerializableObject
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

      refine Symbol.singleton_class do
        def deserialize(string)
          string.to_sym
        end
      end
    end
  end
end

class TypedStruct
  using Typed::Internal::SerializableObject

  class << self
    # フィールドを定義する
    def define(name, typedef, tags = {})
      unless Typed::Internal.supported_type?(typedef)
        raise ArgumentError,
              "typedef #{typedef.inspect} is not supported"
      end

      __attributes[name] = Typed::Internal.as_class_typedef typedef
      __tags[name] = tags

      attr_reader name

      define_method "#{name}=" do |v|
        assign! name, v
      end
    end

    # JSONからパースする
    def deserialize(hash)
      new_hash = {}

      __attributes.each_key do |key|
        typedef = __attributes[key]
        tag = __tags[key]

        json_tag_key = Typed::Internal::JSONTag.json_key_or_nil tag
        json_key = json_tag_key.nil? ? key : json_tag_key.to_sym

        v = hash.fetch(json_key, nil)

        # JSON側に値がなかったら、コンストラクタで初期値を自動的に生成する
        next if v.nil?

        # - が指定されていたら、JSON側に値があっても無視する
        next if Typed::Internal::JSONTag.should_skip? tag

        new_hash[key] = if typedef.respond_to? :deserialize
                          typedef.deserialize v
                        elsif typedef.respond_to? :deserialize_elements
                          typedef.deserialize_elements v, typedef[0]
                        else
                          v
                        end
      end

      new(new_hash)
    end

    def __attributes
      @__attributes ||= {}
    end

    def __tags
      @__tags ||= {}
    end
  end

  # インスタンス化時に初期値を指定する場合、{ [key_symbol] => value } 形式で渡す
  def initialize(init = {})
    self.class.__attributes.each do |name, typedef|
      allow_nil = self.class.__tags[name][:allow] == 'nil'

      zero = Typed::Internal.initial_value typedef, allow_nil
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

  # JSONにシリアライズする
  def serialize
    hash = {}
    self.class.__attributes.each do |name, typedef|
      v = instance_variable_get "@#{name}"

      allow_nil = self.class.__tags[name][:allow] == 'nil'

      tag = self.class.__tags[name]
      json_key = Typed::Internal::JSONTag.json_key_or_nil tag

      next if Typed::Internal::JSONTag.should_skip?(tag)

      if Typed::Internal::JSONTag.omit_empty?(tag)
        # nil許容の場合、値がnilの時以外はキーを省略しない
        next if Typed::Internal.zero_value?(v, typedef) && !allow_nil
        next if v.nil? && allow_nil
      end

      v = v.serialize if v.respond_to? :serialize
      hash[json_key.nil? ? name.to_s : json_key] = v
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
    allow_nil = self.class.__tags[to][:allow] == 'nil'

    return false unless Typed::Internal.type_correct?(typedef, value, allow_nil)

    instance_variable_set "@#{to}", value
    true
  end
end

module TypedSerialize
  using Typed::Internal::SerializableObject

  module JSON
    module_function

    # JSON 文字列に変換する。
    # オブジェクトが serialize() -> Hash メソッドを持つ場合、そのメソッドの返り値 (Hash) を利用する。
    def marshal(v)
      h = v.serialize
      ::JSON.generate h
    end

    # JSON 文字列から typedef で指定した型に変換する。
    # オブジェクトが self.deserialize(Hash) -> T あるいは self.deserialize_elements(Hash, U) -> T<U> のいずれかのメソッドを持つ場合、その結果を使って変換する。
    def unmarshal(data, typedef)
      h = ::JSON.parse data, symbolize_names: true

      if typedef.respond_to? :deserialize_elements
        typedef.deserialize_elements h, typedef[0]
      elsif typedef.respond_to? :deserialize
        typedef.deserialize h
      else
        h
      end
    end
  end

  module YAML
    module_function

    # 単一の YAML 文字列に変換する。
    def marshal(v)
      h = v.serialize
      y = ::YAML.dump h
      y.delete_prefix "---\n"
    end

    # 複数のドキュメントの YAML 文字列に変換する。
    def marshal_stream(list)
      serialized_list = []
      list.each do |v|
        serialized_list.append v.serialize
      end

      y = ::YAML.dump_stream(*serialized_list)
      y.delete_prefix "---\n"
    end

    # 単一の YAML をパースする。
    def unmarshal(data, typedef)
      h = ::YAML.safe_load data, symbolize_names: true, aliases: true

      if typedef.respond_to? :deserialize_elements
        typedef.deserialize_elements h, typedef[0]
      elsif typedef.respond_to? :deserialize
        typedef.deserialize h
      else
        h
      end
    end

    # 複数ドキュメントの YAML をパースする
    def unmarshal_stream(data, typedefs)
      docs = data.split '---'
      docs.filter! do |v|
        v.strip != ''
      end

      ret = []
      typedefs.each do |typedef|
        doc = docs.shift
        ret.append unmarshal(doc, typedef)
      end

      ret
    end
  end
end
