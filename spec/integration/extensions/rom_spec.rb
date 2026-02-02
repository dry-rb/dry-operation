# frozen_string_literal: true

require "spec_helper"

RSpec.describe Dry::Operation::Extensions::ROM do
  include Dry::Monads[:result]

  let(:rom) do
    database_url =
      if RUBY_ENGINE == "jruby"
        "jdbc:sqlite::memory:"
      else
        "sqlite:file::memory:?cache=private"
      end

    ROM.container(:sql, database_url) do |config|
      config.default.create_table(:foo) do
        column :bar, :string
      end

      config.relation(:foo)
    end
  end

  let(:base) do
    Class.new(Dry::Operation) do
      include Dry::Operation::Extensions::ROM

      attr_reader :rom

      def initialize(rom:)
        @rom = rom
        super()
      end
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
        Success(rom.relations[:foo].command(:create).(bar: "bar"))
      end

      def failure
        Failure(:failure)
      end
    end.new(rom: rom)

    instance.()

    expect(rom.relations[:foo].count).to be(0)
  end

  it "acts transparently for the regular flow for a success" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_record
          step count_records
        end
      end

      def create_record
        Success(rom.relations[:foo].command(:create).(bar: "bar"))
      end

      def count_records
        Success(rom.relations[:foo].count)
      end
    end.new(rom: rom)

    expect(
      instance.()
    ).to eql(Success(1))
  end

  it "acts transparently for the regular flow for a failure" do
    instance = Class.new(base) do
      def call
        transaction do
          step create_record
          step count_records
        end
      end

      def create_record
        Success(rom.relations[:foo].command(:create).(bar: "bar"))
      end

      def count_records
        Failure(:failure)
      end
    end.new(rom: rom)

    expect(
      instance.()
    ).to eql(Failure(:failure))
  end

  it "passes options through to the ROM gateway transaction" do
    instance = Class.new(base) do
      def call
        transaction(auto_savepoint: true) do
          step create_record("outer1")

          transaction do
            step create_record("inner1")
            raise Sequel::Rollback
          end

          step create_record("outer2")
        end
      end

      def create_record(value)
        Success(rom.relations[:foo].command(:create).(bar: value))
      end
    end.new(rom: rom)

    expect(instance.()).to be_success
    expect(rom.relations[:foo].to_a.map { |t| t[:bar] }).to match_array(["outer1", "outer2"])
  end
end
