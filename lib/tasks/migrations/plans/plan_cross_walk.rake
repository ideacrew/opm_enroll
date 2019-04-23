require Rails.root.join('lib', 'tasks', 'hbx_import', 'plan_cross_walk_list_parser')
namespace :xml do
  desc "Import plan crosswalk"
  task :plan_cross_walk, [:file] => :environment do |task, args|
    files = Rails.env.test? ? [args[:file]] : Dir.glob(File.join(Rails.root, "db/seedfiles/plan_xmls", Settings.aca.state_abbreviation.downcase, "cross_walk", "**", "*.xml"))

    files.each do |file_path|
      puts "*"*80 unless Rails.env.test?
      puts "processing: #{file_path}" unless Rails.env.test?
      @file_path = file_path
      @current_year = file_path.split("/")[-2].to_i # Retrieve the year of the master xml file you are uploading
      @previous_year = @current_year - 1
      xml = Nokogiri::XML(File.open(@file_path))
      result = Parser::PlanCrossWalkListParser.parse(xml.root.canonicalize, :single => true)
      cross_walks = result.to_hash[:crosswalks]
      cross_walks.each do |row|
        old_hios_id = row["plan_id_#{@previous_year}_hios".to_sym].squish
        new_hios_id = row["plan_id_#{@current_year}_hios".to_sym].squish

        # old model
        new_plans =  Plan.where(hios_id: /#{new_hios_id}/, active_year: @current_year)
        # cat_age_off_renewal_plan =  Plan.where(hios_id: /#{hios_id_cat_age_off_2018}/, active_year: @current_year)
        new_plans.each do |new_plan|
          if new_plan.present? && new_plan.csr_variant_id != "00"
            old_plan = Plan.where(hios_id: /#{old_hios_id}/, active_year: @previous_year, csr_variant_id: /#{new_plan.csr_variant_id}/).first
            if old_plan.present?
              old_plan.update(renewal_plan_id: new_plan.id)
              puts "Old #{@previous_year} plan hios_id #{old_plan.hios_id} renewed with New #{@current_year} plan hios_id: #{new_plan.hios_id}" unless Rails.env.test?
            else
              puts "Old #{@previous_year} plan hios_id #{old_hios_id}-#{new_plan.csr_variant_id} not present." unless Rails.env.test?
            end
          end
        end
        # end of old model

        # new model
        new_products = ::BenefitMarkets::Products::Product.where(hios_id: /#{new_hios_id}/).select{|a| a.active_year == @current_year}
        new_products.each do |new_product|
          if new_product.present? && new_product.csr_variant_id != "00"
            old_product = ::BenefitMarkets::Products::Product.where(hios_id: /#{old_hios_id}/, csr_variant_id: /#{new_product.csr_variant_id}/).select{|a| a.active_year == @previous_year}.first

            if old_product.present?
              old_product.update(renewal_product_id: new_product.id)
              puts "Old #{@previous_year} product hios_id #{old_product.hios_id} renewed with New #{@current_year} product hios_id: #{new_product.hios_id}" unless Rails.env.test?
            else
              puts "Old #{@previous_year} product hios_id #{old_hios_id}-#{new_product.csr_variant_id} not present." unless Rails.env.test?
            end
          end
        end
        # end of new model

        # new model
        # new_products = ::BenefitMarkets::Products::Product.where(hios_id: /#{hios_id_2018}/).select{|a| a.active_year == @current_year}
        # new_products.each do |new_product|
        #   if new_product.present? && new_product.csr_variant_id != "00"
        #     old_product = ::BenefitMarkets::Products::Product.where(hios_id: /#{hios_id_2017}/, csr_variant_id: /#{new_product.csr_variant_id}/).select{|a| a.active_year == @previous_year}.first

        #     if old_product.present?
        #       old_product.update(renewal_product_id: new_product.id)
        #       puts "Old #{@previous_year} product hios_id #{old_product.hios_id} renewed with New #{@current_year} product hios_id: #{new_product.hios_id}"
        #     else
        #       puts "Old #{@previous_year} product hios_id #{hios_id_2017}-#{new_product.csr_variant_id} not present."
        #     end
        #   end
        # end
        # end of new model
      end
    end
  end
end

# namespace :xml do
#   task :plan_cross_walk, [:file] => :environment do |task,args|

#     files = Dir.glob(File.join(Rails.root, "db/seedfiles/plan_xmls/master_xml", "**", "*.xlsx"))
#     files.each do |file_path|
#       @file_path = file_path

#       set_data

#       puts "*"*80
#       puts "processing file: #{@file_name} \n"
#       puts "*"*80

#       sheets = ["IVL HIOS Plan Crosswalk", "SHOP HIOS Plan Crosswalk"]
#       # sheets = ["SHOP HIOS Plan Crosswalk"]

#       sheets.each do |sheet|
#         puts "#{previous_year}-#{current_year} Plan mapping started. (#{sheet}) \n"
#         set_sheet_data(sheet)
#         (@first_row..@last_row).each do |row_number| # update renewal plan_ids
#           @row_data = @sheet_data.row(row_number)
#           set_plan_variables
#           if @new_hios_id.present?
#             find_old_plan_and_update_renewal_plan_id
#           else
#             puts "#{@carrier} plan with #{headers[1]} : #{@old_hios_id} is retired."
#             @rejected_hios_ids_list << @old_hios_id
#           end
#         end
#         puts "#{previous_year}-#{current_year} Plan mapping completed. (#{sheet}) \n"
#         puts "*"*80
#       end

#       puts "#{previous_year}-#{current_year} Plan carry over started.\n"
#       find_and_update_carry_over_plans
#       puts "#{previous_year}-#{current_year} Plan carry over completed.\n"
#       puts "*"*80
#     end

#   end

#   def previous_year
#     @year - 1
#   end

#   def current_year
#     @year
#   end

#   def old_plan_hios_ids
#     @old_plans ||= Plan.where(active_year: previous_year).map(&:hios_id)
#   end

#   def set_plan_variables
#     if @sheet == "SHOP HIOS Plan Crosswalk" && current_year == 2017
#       @carrier, @old_hios_id, @old_plan_name, @new_hios_id, @new_plan_name = @row_data[0], @row_data[1], @row_data[2], @row_data[4], @row_data[5]
#     else
#       @carrier, @old_hios_id, @old_plan_name, @new_hios_id, @new_plan_name = @row_data
#     end
#   end

#   def calculate_last_row_number
#     if current_year == 2016
#       @sheet == "IVL HIOS Plan Crosswalk" ? @sheet_data.last_row : 118
#     else
#       @sheet_data.last_row
#     end
#   end

#   def by_hios_id_and_active_year(hios_id, year)
#     Plan.where(hios_id: /#{hios_id}/, active_year: year)
#   end

#   def by_hios_id_active_year_and_csr_varaint_id(hios_id, year, csr_variant_id)
#     Plan.where(hios_id: /#{hios_id}/, active_year: year, csr_variant_id: /#{csr_variant_id}/)
#   end

#   def set_sheet_data(sheet)
#     @sheet = sheet
#     @sheet_data = @result.sheet(@sheet)
#     @headers = @sheet_data.row(1)
#     @last_row = calculate_last_row_number
#     @first_row = 1
#   end

#   def find_old_plan_and_update_renewal_plan_id
#     new_plans = by_hios_id_and_active_year(@new_hios_id.squish, current_year)
#     new_plans.each do |new_plan|
#       if new_plan.present? && new_plan.csr_variant_id != "00"
#         old_plan = by_hios_id_active_year_and_csr_varaint_id(@old_hios_id.squish, previous_year, new_plan.csr_variant_id).first
#         if old_plan.present?
#           old_plan.update(renewal_plan_id: new_plan.id)
#           puts "Old #{previous_year} plan hios_id #{old_plan.hios_id} renewed with New #{current_year} plan hios_id: #{new_plan.hios_id}"
#           @updated_hios_ids_list << old_plan.hios_id
#         else
#           puts "Old #{previous_year} plan hios_id #{@old_hios_id}-#{new_plan.csr_variant_id} not present."
#         end
#       end
#     end
#   end

#   def set_data
#     @file_path_array = @file_path.split("/")
#     @year = @file_path_array[-2].to_i # Retrieve the year of the master xml file you are uploading
#     @file_name = @file_path_array.last
#     @result = Roo::Spreadsheet.open(@file_path)
#     @updated_hios_ids_list = []
#     @rejected_hios_ids_list = []
#   end

#   def find_and_update_carry_over_plans
#     if previous_year == 2015
#       # for 2016 aetna cross walk
#       @rejected_hios_ids_list << ["77422DC0060002", "77422DC0060004", "77422DC0060005", "77422DC0060006", "77422DC0060008", "77422DC0060010"]
#     end
#     @old_plan_hios_ids = old_plan_hios_ids.map { |str| str[0..13] }.uniq
#     @updated_hios_ids_list = @updated_hios_ids_list.map { |str| str[0..13] }.uniq
#     @no_change_in_hios_ids = @old_plan_hios_ids - (@updated_hios_ids_list + @rejected_hios_ids_list)
#     @no_change_in_hios_ids = @no_change_in_hios_ids.uniq
#     @no_change_in_hios_ids.each do |hios_id|
#       new_plans = by_hios_id_and_active_year(hios_id.squish, current_year)
#       new_plans.each do |new_plan|
#         old_plan = by_hios_id_active_year_and_csr_varaint_id(hios_id.squish, previous_year, new_plan.csr_variant_id).first
#         if old_plan.present? && new_plan.present? && new_plan.csr_variant_id != "00"
#           old_plan.update(renewal_plan_id: new_plan.id)
#           puts "Old #{previous_year} plan hios_id #{old_plan.hios_id} carry overed with New #{current_year} plan hios_id: #{new_plan.hios_id}"
#         else
#           puts " plan not present : #{hios_id}"
#         end
#       end
#     end
#   end

# end
