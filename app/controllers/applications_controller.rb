class ApplicationsController < ApplicationController
  def continue
    task = ApplicationTask.find(params[:id])

    if task.status != "waiting_for_user"
      redirect_to chat_path(3), alert: "This application is not waiting for user action."
      return
    end

    task.update!(
      status: "ready_for_review",
      details: "User completed the required human action. Application is ready for review."
    )

    redirect_to chat_path(3), notice: "Application can now be reviewed."
  end

  def approve
    task = ApplicationTask.find(params[:id])

    if task.status != "ready_for_review"
      redirect_to chat_path(3), alert: "The application must be reviewed before approval."
      return
    end

    task.update!(
      status: "approved",
      details: "User explicitly approved the application for submission."
    )

    redirect_to chat_path(3), notice: "Application approved for submission."
  end
end