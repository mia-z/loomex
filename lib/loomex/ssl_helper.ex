defmodule Loomex.SSLHelper do
  require Logger
  @validity_days 365
  @san_dns_names ["localhost", "dev.local"]
  @san_ip_addresses ["127.0.0.1", "::1"]
  @key_usage [:digitalSignature, :keyEncipherment]
  @extended_key_usage [:serverAuth]
  @common_name_oid {2, 5, 4, 3}
  
  def create() do
    %{:public => pub, :private => priv} = generate_rsa_pair()
    serial = generate_serial()
    subject_dn = {:rdnSequence, [[ {:AttributeTypeAndValue, @common_name_oid, {:printableString, "localhost"}} ]]}
    issuer_dn = subject_dn
    
    {nb, na} = generate_validity(@validity_days)
    validity = {:Validity, {:utcTime, nb}, {:utcTime, na}}
    
    algo_identifier = {:PublicKeyAlgorithm, {1, 2, 840, 113549, 1, 1, 1}, :asn1_NULL}
    subject_pki = {:OTPSubjectPublicKeyInfo, algo_identifier, pub}
    
    signature_algorithm = {:SignatureAlgorithm, {1, 2, 840, 113549, 1, 1, 11}, :asn1_NULL}

    san_extension = build_san(@san_dns_names, @san_ip_addresses)
    key_usage_extension = build_key_usage(@key_usage)
    basic_constraints_extension = build_basic_constraints(false)
    extended_key_usage_extension = build_extended_key_usage(@extended_key_usage)

    extensions = Enum.filter [san_extension, key_usage_extension, basic_constraints_extension, extended_key_usage_extension], &(&1 != nil)

    tbs = {:OTPTBSCertificate,
      :v3,
      serial,
      signature_algorithm,
      issuer_dn,
      validity,
      subject_dn,
      subject_pki,
      :asn1_NOVALUE,
      :asn1_NOVALUE,
      extensions
    }
    
    cert_bits = :public_key.pkix_sign tbs, priv
    
    cert = {
      :OTPCertificate,
      tbs,
      signature_algorithm,
      cert_bits
    }
  
    encoded_cert = :public_key.pkix_encode :OTPCertificate, cert, :otp
    # cert_pem = :public_key.pem_encode [{:Certificate, encoded_cert, :not_encrypted}]
    
    encoded_key = :public_key.pkix_encode :PrivateKeyInfo, priv, :otp
    # key_pem = :public_key.pem_encode [{:PrivateKeyInfo, encoded_key, :not_encrypted}]
    
    %{ cert: encoded_cert, key: {:PrivateKeyInfo, encoded_key}}
  end
  
  defp generate_rsa_pair(bits \\ 2048) do
    private_key = :public_key.generate_key {:rsa, bits, 65537}
    {:RSAPrivateKey, _version, modulus, publicExponent, _privateExponent, _prime1, _prime2, _exponent1, _exponent2, _coefficient, _} = private_key
    %{ public: {:RSAPublicKey, modulus, publicExponent}, private: private_key}
  end
  
  defp generate_serial do
    <<int::128>> = :crypto.strong_rand_bytes(16)
    abs(int)
  end
  
  defp generate_validity(days) do
    now = DateTime.utc_now
    not_before_dt = now
    not_after_dt = DateTime.add now, days, :day
    
    {to_asn1_time(not_before_dt), to_asn1_time(not_after_dt)}
  end

  defp to_asn1_time(time) do
    time_parts = Calendar.strftime(time, "%y%m%d%H%M%S")
    time_parts <> "Z"
  end
  
  defp build_san(dns_names, ip_addresses) do
    dns_map = Enum.map(dns_names, fn dns -> {:dNSName, dns} end)
    ip_map = Enum.map(ip_addresses, fn ip -> 
      charlist = String.to_charlist ip
      case :inet.parse_address(charlist) do
        {:ok, {a, b, c, d}} when is_integer(a) and a <= 255 and b <= 255 and c <= 255 and d <= 255 ->
          ip_binary = <<a::8, b::8, c::8, d::8>>
          {:iPAddress, ip_binary}
  
        {:ok, {a, b, c, d, e, f, g, h}} when is_integer(a) ->
          ip_binary = <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>
          {:iPAddress, ip_binary}
  
        {:error, reason} ->
          Logger.warning "Invalid IP address format in SAN configuration, skipping: #{inspect(ip)} -> reason: #{inspect(reason)}"
          nil
  
        {:ok, other_tuple} ->
          Logger.warning "Unexpected tuple format from :inet.parse_address for SAN, skipping: #{inspect(ip)} -> #{inspect(other_tuple)}"
          nil
      end
    end)
    |> Enum.filter(&(&1 != nil))

    gans = dns_map ++ ip_map

    if Enum.empty? gans do
      nil
    else
      oid = {2, 5, 29, 17}
      is_critical = false
      {:Extension, oid, is_critical, gans}
    end
  end
  
  defp build_key_usage(usages) do
    oid = {2, 5, 29, 15}
    is_critical = true
    {:Extension, oid, is_critical, usages}
  end
  
  defp build_extended_key_usage(usages) do
    oid = {2, 5, 29, 37}
    is_critical = false
    usage_oids = Enum.map usages, &map_extended_usage_oid/1
    {:Extension, oid, is_critical, usage_oids}
  end
  
  defp map_extended_usage_oid(:serverAuth), do: {1, 3, 6, 1, 5, 5, 7, 3, 1}
  defp map_extended_usage_oid(:clientAuth), do: {1, 3, 6, 1, 5, 5, 7, 3, 2}
  defp map_extended_usage_oid(other), do: other
  
  defp build_basic_constraints(is_ca?) do
    oid = {2, 5, 29, 19}
    is_critical = true
    value = {:BasicConstraints, is_ca?, :asn1_NOVALUE}
    {:Extension, oid, is_critical, value}
  end
  
end