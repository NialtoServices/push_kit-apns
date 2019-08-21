# frozen_string_literal: true

RSpec::Matchers.define(:have_accessor) do |field|
  match do |object|
    object.respond_to?(field) && object.respond_to?("#{field}=")
  end

  description do
    "have a reader and writer for ##{field}"
  end

  failure_message do |object|
    "expected #{object.inspect} to respond to `:#{field}` and `:#{field}=`"
  end

  failure_message_when_negated do |object|
    "expected #{object.inspect} not to respond to `:#{field}` or `:#{field}=`"
  end
end
