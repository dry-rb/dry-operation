# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::ActiveRecord do
  include Dry::Monads[:result]

  before :all do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      ActiveRecord::Migration.suppress_messages do
        create_table :x_ar_foo do |t|
          t.string :bar
        end
      end
    end
  end

  after :all do
    ActiveRecord::Schema.define do
      ActiveRecord::Migration.suppress_messages do
        drop_table :x_ar_foo
      end
    end
  end

  after :each do
    model.delete_all
  end

  let(:model) do
    Class.new(ActiveRecord::Base) do
      self.table_name = :x_ar_foo
    end
  end

  let(:base) do
    Class.new(Dry::Operation) do
      include Dry::Operation::Extensions::ActiveRecord
    end
  end

  it "rolls transaction back on failure" do
    instance = Class.new(base) do
      def initialize(model)
        @model = model
        super()
      end

      def call
        transaction do
          step create_record
          step failure
        end
      end

      def create_record
        Success(@model.create(bar: "bar"))
      end

      def failure
        Failure(:failure)
      end
    end.new(model)

    instance.()
    expect(model.count).to be(0)
  end

  it "acts transparently for the regular flow" do
    instance = Class.new(base) do
      def initialize(model)
        @model = model
        super()
      end

      def call
        transaction do
          step create_record
          step count_records
        end
      end

      def create_record
        Success(@model.create(bar: "bar"))
      end

      def count_records
        Success(@model.count)
      end
    end.new(model)

    expect(instance.()).to eql(Success(1))
  end

  it "accepts options for ActiveRecord transaction method" do
    instance = Class.new(base) do
      def initialize(model)
        @model = model
        super()
      end

      def call
        transaction do
          step create_record
          transaction(requires_new: true) do
            step failure
          end
        end
      end

      def create_record
        Success(@model.create(bar: "bar"))
      end

      def failure
        @model.create(bar: "bar")
        Failure(:failure)
      end
    end.new(model)

    instance.()
    expect(model.count).to be(1)
  end
end
