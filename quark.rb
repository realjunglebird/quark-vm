# frozen_string_literal: true

require 'csv'

class Command
  attr_accessor :opcode, :args

  def initialize(opcode, args)
    @opcode = opcode
    @args = args
  end

  # Конвертация в ассоциативный массив
  def to_h
    { opcode: @opcode, args: @args }
  end

end

class Assembler
  def initialize(input_path, output_path, test_mode)
    @input_path = input_path
    @output_path = output_path
    @test_mode = test_mode
  end

  def run
    rows = CSV.read(@input_path)
    intermediate_representation = rows.map { |row| parse_row(row) }

    if @test_mode
      puts "=== Внутреннее представление команд ==="
      intermediate_representation.each_with_index do |cmd, i|
        puts "Команда №#{i}: #{cmd.to_h}"
      end
    end

    File.open(@output_path, "wb") do |f|
      f.write("")
    end
  end

  private

  def parse_row(row)
    operation = row[0]

    args = {}

    case operation
    when "5", "ld"
      # Загрузка константы
      args[1] = row[1].to_i   # Адрес [B]
      args[2] = row[2].to_i   # Константа [C]
    when "4", "rd"
      # Чтение значения из памяти
      args[1] = row[1].to_i   # Адрес [B]
      args[2] = row[2].to_i   # Адрес [C]
    when "2", ""
      # Запись значения в память
      args[1] = row[1].to_i   # Адрес [B]
      args[2] = row[2].to_i   # Смещение [C]
      args[3] = row[3].to_i   # Адрес [D]
    when "1", "popcnt"
      # Унарная операция: popcnt()
      args[1] = row[1].to_i   # Адрес [B]
      args[2] = row[2].to_i   # Адрес [C]
    end

    Command.new(operation, args)
  end
end

if __FILE__ == $0
  if ARGV.size < 3
    puts "Ошибка: Необходимо указать входной и выходной файлы"
    puts "Использование: quark.rb <input.csv> <output.bin> <test_mode:0|1>"
    exit 1
  end

  input_path = ARGV[0]
  output_path = ARGV[1]
  test_mode = ARGV[2] == "1"

  Assembler.new(input_path, output_path, test_mode).run
end