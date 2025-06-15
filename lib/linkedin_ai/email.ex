defmodule LinkedinAi.Email do
  import Swoosh.Email

  def welcome_email(to) do
    new()
    |> to(to)
    |> from({"Linkedin AI", "no-reply@linkedinai.com"})
    |> subject("Welcome to Linkedin AI!")
    |> text_body("Thank you for signing up.")
  end
end
