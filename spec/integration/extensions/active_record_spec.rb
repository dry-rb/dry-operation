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

  it "acts transparently for the regular flow for a success" do
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

  it "acts transparently for the regular flow for a failure" do
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
        Failure(:failure)
      end
    end.new(model)

    expect(
      instance.()
    ).to eql(Failure(:failure))
  end

  it "accepts options for ActiveRecord transaction method" do
    instance = Class.new(base) do
      def initialize(model)
        @model = model
        super()
      end

      def call
        transaction(requires_new: :false) do
          step create_record
        end
      end

      def create_record
        Success(@model.create(bar: "bar"))
      end
    end.new(model)

    expect(ActiveRecord::Base).to receive(:transaction).with(requires_new: :false).and_call_original

    instance.()

    expect(model.count).to be(1)
  end

  xit "works with `requires_new` for nested transactions" do
    instance = Class.new(base) do
      def initialize(model)
        @model = model
        super()
      end

      def call
        transaction do
          step create_record
          transaction(savepoint: true) do
            step failure
          end
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

    expect(model.count).to be(1)
  end
end
