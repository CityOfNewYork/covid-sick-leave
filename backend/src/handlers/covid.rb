require 'dotenv/load'
require 'pdf-forms'
require 'mysql2'

require './src/util'
require './src/clients/ses'
require './src/clients/mysql'

class COVIDHandler

	def initialize(submission, ses, db)
        @submission = submission

        @faq_link = ENV.fetch("FAQ_LINK", "https://www1.nyc.gov/assets/doh/downloads/pdf/imm/covid-19-paid-sick-leave-order-faq.pdf")
        @standing_order_path = "./constants/dohmh_standing_order.pdf"
        @template_path = "./constants/covid_template_04_15_20.pdf"
        @output_folder = "/tmp"

        @submission_id_key = "UniqueID"
        @name_key = ENV.fetch("NAME_KEY", "91060458")
        @has_email_key = ENV.fetch("HAS_EMAIL_KEY", "91060472")
        @patient_email_key = ENV.fetch("PATIENT_EMAIL_KEY", "91060460")
        @patient_address_key = ENV.fetch("PATIENT_ADDRESS_KEY", "91060601")
        @staff_email_key = ENV.fetch("STAFF_EMAIL_KEY", "91060610")
        @symptom_start_key = ENV.fetch("SYMPTOMS_STARTED_KEY")
        @diagnosed_key = ENV.fetch("DIAGNOSED_KEY")
        @is_essential_key = ENV.fetch("IS_ESSENTIAL_KEY", "91164219")
        @date_of_test_key = ENV.fetch("DATE_OF_TEST", "91164009")

        @pdftk = PdfForms.new
        @ses = ses
        @db = db
	end

    def process
        attachments = []

        full_name = "#{@submission[@name_key]["value"]["first"]} #{@submission[@name_key]["value"]["last"]}"
        todays_date = Time.now.strftime("%B %d, %Y")

        pdf_key_map = {
            # Verification Letter Fields
            "Fullname" => full_name,
            "Date" => todays_date,
            "Symptom Start Date" => @submission[@symptom_start_key]["value"],

            # Standing Order Fields
            # all essential
            # "Essential-Fullname" => @submission[@is_essential_key]["value"] == "Yes" ? full_name : "",
            # "Essential-TodayDate" => @submission[@is_essential_key]["value"] == "Yes" ? todays_date : "",
            # "Essential-HotlineCheckbox" => @submission[@is_essential_key]["value"] == "Yes" ? "On" : "",
            # "Essential-HotlineTodayDate" => @submission[@is_essential_key]["value"] == "Yes" ? todays_date : "",
            # "Essential-HotlineTime" => @submission[@is_essential_key]["value"] == "Yes" ? current_time : "",

            # # essential tested positive
            # "Essential-TestedCheckbox" => @submission[@is_essential_key]["value"] == "Yes" && @submission[@diagnosed_key]["value"] == "Yes" ? "On" : "",
            # "Essential-TestDate" => @submission[@is_essential_key]["value"] == "Yes" && @submission[@diagnosed_key]["value"] == "Yes" ? @submission[@date_of_test_key]["value"] : "",
            
            # # essential symptoms
            # "Essential-SymptomsCheckbox" => @submission[@is_essential_key]["value"] == "Yes" && @submission[@diagnosed_key]["value"] == "No" ? "On" : "",

            # # all non-essential
            # "NonEssential-Fullname" => @submission[@is_essential_key]["value"] == "No" ? full_name : "",
            # "NonEssential-TodayDate" => @submission[@is_essential_key]["value"] == "No" ? todays_date : "",

            # # non-essential tested
            # "NonEssential-TestedCheckbox" => @submission[@is_essential_key]["value"] == "No" &&  @submission[@diagnosed_key]["value"] == "Yes" ? "On" : "",
            # "NonEssential-TestDate" => @submission[@is_essential_key]["value"] == "No" &&  @submission[@diagnosed_key]["value"] == "Yes" ? @submission[@date_of_test_key]["value"] : "",

            # # non-essential symptoms
            # "NonEssential-SymptomsCheckbox" => @submission[@is_essential_key]["value"] == "No" &&  @submission[@diagnosed_key]["value"] == "No" ? "On" : ""
        }

        create_dir_unless_exists("#{@output_folder}/#{@submission[@submission_id_key]}")


        if @submission[@diagnosed_key]["value"] == "Yes"
            # attach standing order only
            attachments.push(@standing_order_path)

        else
            # attach verification letter
            tmp_output_path = "#{@output_folder}/#{@submission[@submission_id_key]}/nyc_sickleave_letter_tmp.pdf"
            output_path = "#{@output_folder}/#{@submission[@submission_id_key]}/nyc_sickleave_letter.pdf"
            @pdftk.fill_form @template_path, tmp_output_path, pdf_key_map
            # Run PDFTK from the OS to protect the document from editing
            `pdftk #{tmp_output_path} output #{output_path} owner_pw #{ENV.fetch("DOCUMENT_PASSWORD")} allow printing`
            attachments.push(output_path)

            # attach standing order
            attachments.push(@standing_order_path)
        end

        text = nil
        html = nil
        to_addr = nil

        has_email = @submission[@has_email_key]["value"] == "Yes"
        if has_email
            to_addr = @submission[@patient_email_key]["value"]

            text = "Dear #{full_name},\n\nPlease see attached a document known as the standing order allowing you to use paid sick leave at this time. Please fill out Appendix B or Appendix C depending on the type of business you work for and show this document to your employer as well as any other documentation attached to this email or your covid test results if you have them.\n\nMore information is available on the Department of Health and Mental Hygiene's FAQ page: #{@faq_link}\n\nNothing in this email shall preclude a hospital or other healthcare provider from requiring that its employees provide additional documentation or information that confirms the need for the self-quarantine to its office of occupational health services or as otherwise directed.\n\nSincerely,\nNYC Department of Health and Mental Hygiene"

            html = "Dear #{full_name},<br><br>" +
                "Please see attached a document known as the standing order allowing you to use paid sick leave at this time. Please fill out Appendix B or Appendix C depending on the type of business you work for and show this document to your employer as well as any other documentation attached to this email or your COVID-19 test results if you have them.<br><br>" +
                "More information is available on the Department of Health and Mental Hygiene's FAQ page: #{@faq_link}<br><br>" +
                "Nothing in this email shall preclude a hospital or other healthcare provider from requiring that its employees provide additional documentation or information that confirms the need for the self-quarantine to its office of occupational health services or as otherwise directed.<br><br>" +
                "Sincerely,<br>" +
                "NYC Department of Health and Mental Hygiene<br>"


        else    
            to_addr = ENV.fetch("TO_ADDR_NO_EMAIL")
            patient_addr = @submission[@patient_address_key]["value"]
            text = "Hello,\n\nPlease print the attached document and mail to:\n\n#{full_name}\n#{patient_addr["address"]}\n#{patient_addr["address2"]}\n#{patient_addr["city"]}, #{patient_addr["state"]} #{patient_addr["zip"]}\n\nSincerely,\nNYC Cityhall"
            html = "Hello,<br><br>" +
                "Please print the attached document(s) and mail to:<br><br>" +
                "#{full_name}<br>" +
                "#{patient_addr["address"]}<br>" +
                "#{patient_addr["address2"]}<br>" +
                "#{patient_addr["city"]}, #{patient_addr["state"]} #{patient_addr["zip"]}<br><br>" +
                "Sincerely,<br>" + 
                "NYC Department of Health and Mental Hygiene"
        end

        type = @submission[@diagnosed_key]["value"] == "Yes" ? "POSITIVE" : "NO_TEST"
        @ses.send(
            "Sick Leave Verification Document", 
            text,
            html, 
            to_addr,
            attachments: attachments,
            sendername: ENV.fetch("FROM_ADDR_NAME", "NYC Cityhall")
        )
        if not ENV.fetch("TENANCY") == "staging"
            @db.add_submission(type, has_email)
        end
    end
end
