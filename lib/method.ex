defmodule Method do
  def parse(method) when is_binary method do
    method = case String.downcase method do
      "get" -> :GET
      "post" -> :POST
      "put" -> :PUT
      "patch" -> :PATCH
      "options" -> :OPTIONS
      "head" -> :HEAD
      "delete" -> :DELETE
      _ -> :INVALID_METHOD
    end
    method
  end
  
  def get do :GET end
  def post do :POST end
  def patch do :PATCH end
  def delete do :DELETE end
  def put do :PUT end
  def options do :OPTIONS end
  def head do :HEAD end

end