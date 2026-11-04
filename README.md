# Sera

Sera is an AI assistant built with Ruby on Rails. It supports AI-powered chat, searching information in uploaded documents, and guided application and browser workflows.

## Features

- Create and revisit conversations.
- Search previous chats.
- Choose from available AI models and refresh the model list.
- Attach PDF and image files to chats. Sera extracts text or information from supported attachments and indexes it for later document searches.
- Ask questions about information in uploaded documents.
- Use guided application and browser workflows. Some steps require human input or explicit approval.

## Technology

- Ruby 3.4.10
- Ruby on Rails 8.1
- SQLite
- RubyLLM, with Gemini and Groq provider configuration
- Active Storage for attachments
- Playwright-related dependencies for browser workflows

## Requirements

- Ruby 3.4.10 and Bundler
- SQLite
- Internet access for AI-provider requests
- API keys for the AI providers you intend to use

On Linux, installing Ruby gems may also require a compiler toolchain and SQLite development headers.

## Setup

Clone the repository and enter its directory:

```sh
git clone <repository-url>
cd sera