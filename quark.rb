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

  # Главный алгоритм ассемблера
  def run
    rows = CSV.read(@input_path)
    intermediate_representation = rows.map { |row| parse_row(row) }
    machine_code = intermediate_representation.map.with_index do |cmd, i|
      begin
        assemble(cmd)
      rescue => e
        puts "Ошибка при обработке строки #{i+1}: #{e.message}"
        exit 1
        #raise
      end
    end

    # Записываем машинный код в файл
    write_machine_code_to_file(machine_code, @output_path)

    if @test_mode
      puts "=== Внутреннее представление команд ==="
      intermediate_representation.each_with_index do |cmd, i|
        puts "Команда №#{i}: #{cmd.to_h}"
      end

      puts
      puts "=== Машинное представление команд ==="
      machine_code.each_with_index do |cmd, i|
        puts "Команда №#{i}: #{cmd}"
      end

      puts
      puts "Размер двоичного файла в байтах: #{File.size(@output_path)} байт"
    end
  end

  private

  # Запись набора машинных инструкций в файл
  def write_machine_code_to_file(commands, filename)
    File.open(filename, "wb") do |file|
      commands.each do |cmd|
        bytes = cmd.scan(/.{8}/).map { |byte| byte.to_i(2) }

        file.write(bytes.pack("C*"))
      end
    end
  end

  # Перевод из промежуточного представления в машинное
  def assemble(cmd)
    operation = cmd::opcode
    args = cmd::args
    result = ""

    case operation
    when "5", "ldc"
      opcode = 5.to_s(2).rjust(3, '0')
      arg1 = parse_register(args[0]).to_s(2).rjust(3, '0')
      arg2 = args[1].to_i.to_s(2).rjust(16, '0')
      result = "#{arg2}#{arg1}#{opcode}".rjust(40, '0')
    when "4", "ldr"
      opcode = 4.to_s(2).rjust(3, '0')
      arg1 = parse_register(args[0]).to_s(2).rjust(3, '0')
      arg2 = parse_register(args[1]).to_s(2).rjust(3, '0')
      result = "#{arg2}#{arg1}#{opcode}".rjust(40, '0')
    when "2", "str"
      opcode = 2.to_s(2).rjust(3, '0')
      arg1 = parse_register(args[0]).to_s(2).rjust(3, '0')
      arg2 = args[1].to_i.to_s(2).rjust(12, '0')
      arg3 = parse_register(args[2]).to_s(2).rjust(3, '0')
      result = "#{arg3}#{arg2}#{arg1}#{opcode}".rjust(40, '0')
    when "1", "popcnt"
      opcode = 1.to_s(2).rjust(3, '0')
      arg1 = parse_register(args[0]).to_s(2).rjust(3, '0')
      arg2 = args[1].to_i.to_s(2).rjust(31, '0')
      result = "#{arg2}#{arg1}#{opcode}".rjust(40, '0')
    else
      puts "Не удалось ассемблировать операцию: #{cmd.to_h}"
    end

    result
  end

  # Перевод исходников в промежуточное представление
  def parse_row(row)
    row.map! { |token| token.delete(' ') }
    operation = row[0].downcase
    args = {}

    case operation
    when "5", "ldc"
      # Загрузка константы
      args[0] = row[1]   # Адрес регистра [B]
      args[1] = row[2]   # Константа [C]
    when "4", "ldr"
      # Чтение значения из памяти
      args[0] = row[1]   # Адрес регистра [B]
      args[1] = row[2]   # Адрес регистра [C]
    when "2", "str"
      # Запись значения в память
      args[0] = row[1]   # Адрес регистра [B]
      args[1] = row[2]   # Смещение [C]
      args[2] = row[3]   # Адрес регистра [D]
    when "1", "popcnt"
      # Унарная операция: popcnt()
      args[0] = row[1]   # Адрес регистра [B]
      args[1] = row[2]   # Адрес [C]
    else
      puts "Неизвестная операция: #{operation}"
    end

    Command.new(operation, args)
  end

  # Валидация регистра и преобразование его кода в адрес
  def parse_register(reg)
    registers = %w[R0 R1 R2 R3 R4 R5 R6 R7]

    if registers.include?(reg)
      reg.delete_prefix('R').to_i
    else
      raise "Ошибка: регистр #{reg} не существует!"
    end
  end

end

# Чтение бинарного файла и вывод всех содержащихся в нём команд
def read_binary_file(filename)
  data = File.binread(filename)
  records = data.bytes.each_slice(5).to_a

  puts "Количество команд: #{records.size}"
  puts "Двоичное представление записей:"
  records.each_with_index do |record, i|
    puts "Запись #{i+1}: #{record.map { |b| b.to_s(2).rjust(8, '0') }.join(' ') }"
  end
  puts
  puts "Шестнадцатеричное представление записей:"
  records.each_with_index do |record, i|
    puts "Запись #{i+1}: #{record.reverse.map { |byte| "0x#{byte.to_s(16).upcase.rjust(2, '0')}" }.join(' ') }"
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

  if test_mode
    puts
    puts
    puts "=== Проверка файла ==="
    read_binary_file(output_path)
  end

end