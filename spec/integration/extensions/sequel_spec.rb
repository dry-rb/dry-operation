# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::Sequel do
  include Dry::Monads[:result]

  let(:db) do
    Sequel.sqlite
  end

  before do
    db.create_table(:users) do
      primary_key :id
      String :name
    end
  end

  after do
    db.drop_table(:users)
  end

  let(:base) do
    Class.new(Dry::Operation) do
      include Dry::Operation::Extensions::Sequel

      attr_reader :db

      def initialize(db:)
        @db = db
        super()
      end
    end
  end

  it "rolls transaction back on failure" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_user
          step failure
        end
      end

      def create_user
        Success(db[:users].insert(name: "John"))
      end

      def failure
        Failure(:failure)
      end
    end.new(db: db)

    instance.()
    expect(db[:users].count).to be(0)
  end

  it "acts transparently for the regular flow for a success" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_user
          step count_users
        end
      end

      def create_user
        Success(db[:users].insert(name: "John"))
      end

      def count_users
        Success(db[:users].count)
      end
    end.new(db: db)

    expect(instance.()).to eql(Success(1))
  end

  it "acts transparently for the regular flow for a failure" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_user
          step failure
        end
      end

      def create_user
        Success(db[:users].insert(name: "John"))
      end

      def failure
        Failure(:failure)
      end
    end.new(db: db)

    expect(instance.()).to eql(Failure(:failure))
  end

  it "accepts options for Sequel transaction method" do
    instance = Class.new(base) do
      def call
        transaction(isolation: :serializable) do
          step create_user
        end
      end

      def create_user
        Success(db[:users].insert(name: "John"))
      end
    end.new(db: db)

    expect(db).to receive(:transaction).with(isolation: :serializable)

    instance.()
  end

  xit "works with `requires_new` for nested transactions" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_user
          transaction(requires_new: true) do
            step failure
          end
        end
      end

      def create_user
        Success(db[:users].insert(name: "John"))
      end

      def failure
        Failure(:failure)
      end
    end.new(db: db)

    instance.()

    expect(db[:users].count).to be(1)
  end
end
