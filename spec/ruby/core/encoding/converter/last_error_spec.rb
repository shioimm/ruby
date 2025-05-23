# encoding: binary
require_relative '../../../spec_helper'

describe "Encoding::Converter#last_error" do
  it "returns nil when the no conversion has been attempted" do
    ec = Encoding::Converter.new('ascii','utf-8')
    ec.last_error.should be_nil
  end

  it "returns nil when the last conversion did not produce an error" do
    ec = Encoding::Converter.new('ascii','utf-8')
    ec.convert('a'.dup.force_encoding('ascii'))
    ec.last_error.should be_nil
  end

  it "returns nil when #primitive_convert last returned :destination_buffer_full" do
    ec = Encoding::Converter.new("utf-8", "iso-2022-jp")
    ec.primitive_convert(+"\u{9999}", +"", 0, 0, partial_input: false) \
      .should == :destination_buffer_full
    ec.last_error.should be_nil
  end

  it "returns nil when #primitive_convert last returned :finished" do
    ec = Encoding::Converter.new("utf-8", "iso-8859-1")
    ec.primitive_convert("glark".dup.force_encoding('utf-8'), +"").should == :finished
    ec.last_error.should be_nil
  end

  it "returns nil if the last conversion succeeded but the penultimate failed" do
    ec = Encoding::Converter.new("utf-8", "iso-8859-1")
    ec.primitive_convert(+"\xf1abcd", +"").should == :invalid_byte_sequence
    ec.primitive_convert("glark".dup.force_encoding('utf-8'), +"").should == :finished
    ec.last_error.should be_nil
  end

  it "returns an Encoding::InvalidByteSequenceError when #primitive_convert last returned :invalid_byte_sequence" do
    ec = Encoding::Converter.new("utf-8", "iso-8859-1")
    ec.primitive_convert(+"\xf1abcd", +"").should == :invalid_byte_sequence
    ec.last_error.should be_an_instance_of(Encoding::InvalidByteSequenceError)
  end

  it "returns an Encoding::UndefinedConversionError when #primitive_convert last returned :undefined_conversion" do
    ec = Encoding::Converter.new("utf-8", "iso-8859-1")
    ec.primitive_convert(+"\u{9876}", +"").should == :undefined_conversion
    ec.last_error.should be_an_instance_of(Encoding::UndefinedConversionError)
  end

  it "returns an Encoding::InvalidByteSequenceError when #primitive_convert last returned :incomplete_input" do
    ec = Encoding::Converter.new("EUC-JP", "ISO-8859-1")
    ec.primitive_convert(+"\xa4", +"", nil, 10).should == :incomplete_input
    ec.last_error.should be_an_instance_of(Encoding::InvalidByteSequenceError)
  end

  it "returns an Encoding::InvalidByteSequenceError when the last call to #convert produced one" do
    ec = Encoding::Converter.new("utf-8", "iso-8859-1")
    exception = nil
    -> {
      ec.convert("\xf1abcd")
    }.should raise_error(Encoding::InvalidByteSequenceError) { |e|
      exception = e
    }
    ec.last_error.should be_an_instance_of(Encoding::InvalidByteSequenceError)
    ec.last_error.message.should == exception.message
  end

  it "returns an Encoding::UndefinedConversionError when the last call to #convert produced one" do
    ec = Encoding::Converter.new("utf-8", "iso-8859-1")
    exception = nil
    -> {
      ec.convert("\u{9899}")
    }.should raise_error(Encoding::UndefinedConversionError) { |e|
      exception = e
    }
    ec.last_error.should be_an_instance_of(Encoding::UndefinedConversionError)
    ec.last_error.message.should == exception.message
    ec.last_error.message.should include "from UTF-8 to ISO-8859-1"
  end

  it "returns the last error of #convert with a message showing the transcoding path" do
    ec = Encoding::Converter.new("iso-8859-1", "Big5")
    exception = nil
    -> {
      ec.convert("\xE9") # é in ISO-8859-1
    }.should raise_error(Encoding::UndefinedConversionError) { |e|
      exception = e
    }
    ec.last_error.should be_an_instance_of(Encoding::UndefinedConversionError)
    ec.last_error.message.should == exception.message
    ec.last_error.message.should include "from ISO-8859-1 to UTF-8 to Big5"
  end
end
