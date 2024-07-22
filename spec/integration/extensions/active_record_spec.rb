# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::ActiveRecord do
  include Dry::Monads[:result]

  let!(:model) do
    Class.new(ActiveRecord::Base) do
      self.table_name = :foo
    end
  end

  before :all do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Schema.define do
      create_table :foo do |t|
        t.string :bar
      end
    end
  end

  after :each do
    model.delete_all
  end

  let(:base) do
    Class.new(Dry::Operation) do
      include Dry::Operation::Extensions::ActiveRecord
    end
  end

  it "rolls transaction back on failure" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_record
          step failure
        end
      end

      def create_record
        Success(ActiveRecord::Base.descendants.first.create(bar: "bar"))
      end

      def failure
        Failure(:failure)
      end
    end.new

    instance.()
    expect(model.count).to be(0)
  end

  it "acts transparently for the regular flow" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_record
          step count_records
        end
      end

      def create_record
        Success(ActiveRecord::Base.descendants.first.create(bar: "bar"))
      end

      def count_records
        Success(ActiveRecord::Base.descendants.first.count)
      end
    end.new

    expect(
      instance.()
    ).to eql(Success(1))
  end

  it "ensures new savepoints for nested transactions" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_record
          transaction do
            step failure
          end
        end
      end

      def create_record
        Success(ActiveRecord::Base.descendants.first.create(bar: "bar"))
      end

      def failure
        ActiveRecord::Base.descendants.first.create(bar: "bar")
        Failure(:failure)
      end
    end.new

    instance.()
    expect(model.count).to be(1)
  end
end
