class ApplicationAssistantTool < RubyLLM::Tool
  desc "Manage an application workflow. Use this when the user asks SERA to apply for an exam, course, job, or other application."

  param :action, desc: "The action to perform: prepare, human_help, continue, review, or submit"
  param :application_name, desc: "The name of the application"

  def execute(action:, application_name:)
    task = ApplicationTask.find_or_initialize_by(
      application_name: application_name
    )

    case action
    when "prepare"
      task.status = "preparing"
      task.details = "SERA is gathering information and preparing the application."
      task.save!

      "Application #{application_name} is being prepared. " \
      "Use the user's stored documents to gather the required information. " \
      "Do not submit anything yet."

    when "human_help"
      task.status = "waiting_for_user"
      task.details = "Human action is required, such as CAPTCHA, OTP, payment authorization, or identity verification."
      task.save!

      "Human action is required for the #{application_name} application. " \
      "Tell the user exactly what they need to complete, then wait for confirmation."

 
    when "continue"
      if task.status != "waiting_for_user"
        return "There is no application currently waiting for user action."
      end

      task.status = "ready_for_review"
      task.details = "User completed the required human action. Application is ready for review."
      task.save!

      "The user completed the required human action. " \
      "The #{application_name} application is now ready for review."

    when "review"
      task.status = "ready_for_review"
      task.details = "Application information has been prepared and is waiting for user review."
      task.save!

      "The #{application_name} application is ready for review. " \
      "Ask the user to review the information carefully. Do not submit yet."

   when "submit"
    if task.status != "ready_for_review"
      return "The #{application_name} application is not ready for submission. " \
             "The user must review the application first."
    end

    task.status = "approved"
    task.details = "User explicitly approved the application for submission."
    task.save!

    "The user has explicitly approved the #{application_name} application for submission. " \
    "The application is approved, but it has NOT been submitted yet."

    else
      "Unknown application action: #{action}"
    end
  end
end