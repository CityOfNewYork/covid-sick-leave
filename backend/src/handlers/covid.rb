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
        @standing_order_template_path = "./constants/dohmh_standing_order_05_14_20.pdf"
        @symptom_verification_template_path = "./constants/covid_template_04_15_20.pdf"
        @positive_verification_template_path = "./constants/covid_template_positive_04_15_20.pdf"
        @output_folder = "/tmp"

        @submission_id_key = "UniqueID"
        @name_key = ENV.fetch("NAME_KEY", "91060458")
        @has_email_key = ENV.fetch("HAS_EMAIL_KEY", "91060472")
        @patient_email_key = ENV.fetch("PATIENT_EMAIL_KEY", "91060460")
        @patient_address_key = ENV.fetch("PATIENT_ADDRESS_KEY", "91060601")
        @staff_email_key = ENV.fetch("STAFF_EMAIL_KEY", "91060610")
        @symptom_start_key = ENV.fetch("SYMPTOMS_STARTED_KEY")
        @diagnosed_key = ENV.fetch("DIAGNOSED_KEY")

        @date_of_test_key = ENV.fetch("DATE_OF_TEST", "92571758")
        @worker_category = ENV.fetch("WORKER_CATEGORY", "92558530")
        @has_provider_note = ENV.fetch("HAS_PROVIDER_NOTE", "92559836")
        @provider_name = ENV.fetch("PROVIDER_NAME", "92560091")
        @provider_note_date = ENV.fetch("PROVIDER_NOTE_DATE", "92560173")
        @has_hospital_note = ENV.fetch("HAS_HOSPITAL_NOTE", "92560269")
        @hospital_name = ENV.fetch("HOSPITAL_NAME", "92560319")
        @hospital_note_date = ENV.fetch("HOSPITAL_DATE", "92573124")

        @full_name = "#{@submission[@name_key]["value"]["first"]} #{@submission[@name_key]["value"]["last"]}"
        
        # TODO: make this work with DLS (not urgent because requirement is approx. current time)
        local_time = Time.now.getlocal('-04:00')
        @todays_date = local_time.strftime("%B %d, %Y")
        @current_time = local_time.strftime("%I:%M %p")

        @verification_output_path = "#{@output_folder}/#{@submission[@submission_id_key]}/nyc_paidleave_letter.pdf"
        @tmp_verification_output_path = "#{@output_folder}/#{@submission[@submission_id_key]}/nyc_paidleave_letter_tmp.pdf"
        @standing_order_output_path = "#{@output_folder}/#{@submission[@submission_id_key]}/dohmh_standing_order.pdf"

        @pdftk = PdfForms.new
        @ses = ses
        @db = db
	end

    def fill_verification_letter()
        verification_pdf_key_map = {
            "Fullname" => @full_name,
            "Date" => @todays_date,
            "Symptom Start Date" => @submission[@symptom_start_key]["value"]
        }
        template_path = @submission[@diagnosed_key]["value"] == "Yes" ? @positive_verification_template_path : @symptom_verification_template_path
        @pdftk.fill_form template_path, @tmp_verification_output_path, verification_pdf_key_map
        # Run PDFTK from the OS to protect the document from editing
        `pdftk #{@tmp_verification_output_path} output #{@verification_output_path} owner_pw #{ENV.fetch("DOCUMENT_PASSWORD")} allow printing`
    end

    def fill_standing_order()
        category_keys_map = {
            "Non-essential Worker" => {
                "NonEssential-Fullname" => @full_name,
                "NonEssential-TodayDate" => @todays_date,

                # reason fields
                "NonEssential-TestedCheckbox" => @submission[@diagnosed_key]["value"] == "Yes" ? "On" : "",
                "NonEssential-TestDate" => @submission[@diagnosed_key]["value"] == "Yes" ? @submission[@date_of_test_key]["value"] : "",
                "NonEssential-SymptomsCheckbox" => @submission[@diagnosed_key]["value"] == "No" ? "On" : ""
            },
            "Healthcare Worker" => {
                "Healthcare-Fullname" => @full_name,
                "Healthcare-TodayDate" => @todays_date,

                # question (1) fields
                "Healthcare-TestedCheckbox" => @submission[@diagnosed_key]["value"] == "Yes" ? "On" : "",
                "Healthcare-TestDate" => @submission[@diagnosed_key]["value"] == "Yes" ? @submission[@date_of_test_key]["value"] : "",
                "Healthcare-SymptomsCheckbox" => @submission[@diagnosed_key]["value"] == "No" ? "On" : "",

                # question (2) fields
                "Healthcare-PhysicianExamination" => @submission[@has_provider_note]["value"] == "Yes" ? "On" : "",
                "Healthcare-PhysicianName" => @submission[@has_provider_note]["value"] == "Yes" ? @submission[@provider_name]["value"] : "",
                "Healthcare-PhysicianDate" => @submission[@has_provider_note]["value"] == "Yes" ? @submission[@provider_note_date]["value"] : "",

                "Healthcare-HotlineExamination" => @submission[@has_hospital_note]["value"] == "No" && @submission[@has_provider_note]["value"] == "No" ? "On" : "",
                "Healthcare-HotlineDate" => @submission[@has_hospital_note]["value"] == "No" && @submission[@has_provider_note]["value"] == "No" ? @todays_date : "",
                "Healthcare-HotlineTime" => @submission[@has_hospital_note]["value"] == "No" && @submission[@has_provider_note]["value"] == "No" ? @current_time : "",
                
                "Healthcare-HospitalExamination" => @submission[@has_hospital_note]["value"] == "Yes" ? "On" : "",
                "Healthcare-HospitalName" => @submission[@has_hospital_note]["value"] == "Yes" ? @submission[@hospital_name]["value"] : "",
                "Healthcare-HospitalDate" => @submission[@has_hospital_note]["value"] == "Yes" ? @submission[@hospital_note_date]["value"] : ""
            },
            "Essential Worker" => {
                "Essential-Fullname" => @full_name,
                "Essential-TodayDate" => @todays_date,

                # question (1) fields
                "Essential-TestedCheckbox" => @submission[@diagnosed_key]["value"] == "Yes" ? "On" : "",
                "Essential-TestDate" => @submission[@diagnosed_key]["value"] == "Yes" ? @submission[@date_of_test_key]["value"] : "",
                "Essential-SymptomsCheckbox" => @submission[@diagnosed_key]["value"] == "No" ? "On" : "",

                # question (2) fields
                "Essential-PhysicianExamination" => @submission[@has_provider_note]["value"] == "Yes" ? "On" : "",
                "Essential-PhysicianName" => @submission[@has_provider_note]["value"] == "Yes" ? @submission[@provider_name]["value"] : "",
                "Essential-PhysicianDate" => @submission[@has_provider_note]["value"] == "Yes" ? @submission[@provider_note_date]["value"] : "",

                "Essential-HotlineExamination" => @submission[@has_hospital_note]["value"] == "No" && @submission[@has_provider_note]["value"] == "No" ? "On" : "",
                "Essential-HotlineDate" => @submission[@has_hospital_note]["value"] == "No" && @submission[@has_provider_note]["value"] == "No" ? @todays_date : "",
                "Essential-HotlineTime" => @submission[@has_hospital_note]["value"] == "No" && @submission[@has_provider_note]["value"] == "No" ? @current_time : "",
                
                "Essential-HospitalExamination" => @submission[@has_hospital_note]["value"] == "Yes" ? "On" : "",
                "Essential-HospitalName" => @submission[@has_hospital_note]["value"] == "Yes" ? @submission[@hospital_name]["value"] : "",
                "Essential-HospitalDate" => @submission[@has_hospital_note]["value"] == "Yes" ? @submission[@hospital_note_date]["value"] : ""
            }
        }
        @pdftk.fill_form @standing_order_template_path, @standing_order_output_path, category_keys_map[@submission[@worker_category]["value"]]
    end

    def email_documents()
        text = nil
        html = nil
        to_addr = nil
        should_email = @submission[@has_email_key]["value"] == "Yes"
        if should_email
            to_addr = @submission[@patient_email_key]["value"]

            text = "Dear #{@full_name},\n\nPlease see attached a document known as the standing order allowing you to use paid sick leave at this time. Please fill out Appendix B or Appendix C depending on the type of business you work for and show this document to your employer as well as any other documentation attached to this email or your covid test results if you have them.\n\nMore information is available on the Department of Health and Mental Hygiene's FAQ page: #{@faq_link}\n\nNothing in this email shall preclude a hospital or other healthcare provider from requiring that its employees provide additional documentation or information that confirms the need for the self-quarantine to its office of occupational health services or as otherwise directed.\n\nSincerely,\nNYC Department of Health and Mental Hygiene"

            html = "Dear #{@full_name},<br><br>" +
                "Please see attached a document known as the standing order allowing you to use paid sick leave at this time. Please fill out Appendix B or Appendix C depending on the type of business you work for and show this document to your employer as well as any other documentation attached to this email or your COVID-19 test results if you have them.<br><br>" +
                "More information is available on the Department of Health and Mental Hygiene's FAQ page: #{@faq_link}<br><br>" +
                "Nothing in this email shall preclude a hospital or other healthcare provider from requiring that its employees provide additional documentation or information that confirms the need for the self-quarantine to its office of occupational health services or as otherwise directed.<br><br>" +
                "Sincerely,<br>" +
                "NYC Department of Health and Mental Hygiene<br>"

        else    
            to_addr = ENV.fetch("TO_ADDR_NO_EMAIL")
            patient_addr = @submission[@patient_address_key]["value"]
            text = "Hello,\n\nPlease print the attached document and mail to:\n\n#{@full_name}\n#{patient_addr["address"]}\n#{patient_addr["address2"]}\n#{patient_addr["city"]}, #{patient_addr["state"]} #{patient_addr["zip"]}\n\nSincerely,\nNYC Cityhall"
            html = "Hello,<br><br>" +
                "Please print the attached document(s) and mail to:<br><br>" +
                "#{@full_name}<br>" +
                "#{patient_addr["address"]}<br>" +
                "#{patient_addr["address2"]}<br>" +
                "#{patient_addr["city"]}, #{patient_addr["state"]} #{patient_addr["zip"]}<br><br>" +
                "Sincerely,<br>" + 
                "NYC Department of Health and Mental Hygiene"
        end
        @ses.send(
            "Paid Leave Verification Document", 
            text,
            html, 
            to_addr,
            attachments: [@verification_output_path, @standing_order_output_path],
            sendername: ENV.fetch("FROM_ADDR_NAME", "NYC Department of Health and Mental Hygiene")
        )
        if not ENV.fetch("TENANCY") == "staging"
            type = @submission[@diagnosed_key]["value"] == "Yes" ? "POSITIVE" : "NO_TEST"
            @db.add_submission(type, should_email)
        end
    end


    def process
        create_dir_unless_exists("#{@output_folder}/#{@submission[@submission_id_key]}")
        fill_verification_letter()
        fill_standing_order()
        email_documents()
    end
end
