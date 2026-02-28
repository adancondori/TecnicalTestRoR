necesito que creemos un proyecto con API y interfaces
Este proyecto servidor para ralizar una prueba tecnica, para postulantes al puesto de `Senior Payment Backend`, vamos a realizar un proyecto similar a Xendit o PayFast, POR LO TANTO ESTE PROYECTO SOLO DEBE TENER LO NECESARIO NO DEBE SER UN PROYECTO ROBOSTO

En esta primera fase crearemos el Server proveedor de Pagos

Implementaremos un proyecto con API expuesta para:
APi para crear una nueva conexion: 
Consiste en crear un nuevo cliente para nosotros
Nosotros debemos tener 5 cliente (negocios) creados, cada cliente tendra su propia jwt user, password, secret-key, secret-public, estos servirar para conexxiones API futuras a nuestra API 


- Tokenizacion de Tarjeta con 3Ds y sin 3Ds
- Pago con Tarjeta Tokenizada con 3Ds y sin 3Ds
- Pago con Tarjeta con 3Ds y sin 3Ds
- Pago con eWallet
- Pago con QR

el flujo para la tokenizacion sera
- cada conexion api requier user y password
- el cliente se conectara a nuestra API el cual recibiremos dato necsarios de la tarjeta cvv etc, ademas de un url del webhook para responderle, procederemos a validar si el Numero de tarjeta requiere 3DS, dentro del sistema se crear un payment_method_type=CARD
- Si requiere 3Ds se retorna un atributen el payload requiere3ds=true y se retorna la url del challenge, esta url nosotros le proveemos el cual se conecta a nuestro sistema donde habra un challenge donde digitara siempre 1234, si colaca ese numero, la respuesta se la daremos a la url del webhook, esta respuesta debemos cifrarla el cliente debe decifrarlo con su secret-key que se provee 
- Para pagos con Tarjeta tokenizada se envia en el body datos necesario mas el token_key generado anteriormente en la tokenizacion
- Para pagos directo con la Tarjeta se debe enviar los datos de la Tarjeta y el server valida si requere 3ds o no si nos requiere directamente se hacer el debito y se responde al cliente
- Agrega Refund
- Agrega Void

ESTRUCTURA DE API RESPONSE:
{
    "actions": [
        {
            "action": "AUTH",
            "method": "GET",
            "qr_code": null,
            "url": "https://redirect.xendit.co/authentications/699f4f318434acc54755c8a0/render?api_key=xnd_public_development_ZiYIxjTj5AWZm7jevKUM8uXQ34YBi627VRwI8oJzahhMPyItauD_lDjQmZUjzX7q",
            "url_type": "WEB"
        }
    ],
    "amount": 100,
    "business_id": "697388ec8effe7f2421362c4",
    "capture_method": "AUTOMATIC",
    "card_verification_results": null,
    "channel_properties": null,
    "country": "US",
    "created": "2026-02-25T19:36:16.411447213Z",
    "currency": "USD",
    "customer_id": "cust-8b2235e4-4cdd-48dd-a61c-e2b869b768cc",
    "description": null,
    "failure_code": null,
    "id": "pr-a2eaef20-459b-4471-b4d6-239b9de18fdf",
    "initiator": "CUSTOMER",
    "items": null,
    "metadata": null,
    "payment_method": {
        "card": {
            "card_data_id": "61f632879e9e27001a8165b9",
            "card_information": {
                "cardholder_email": "adan@playbypoint.com",
                "cardholder_first_name": "adan",
                "cardholder_last_name": "condori",
                "cardholder_name": null,
                "cardholder_phone_number": "+639171234567",
                "country": "ID",
                "expiry_month": "12",
                "expiry_year": "2027",
                "fingerprint": "61f632879e9e27001a8165b9",
                "issuer": "BRI",
                "masked_card_number": "400000XXXXXX1091",
                "network": "VISA",
                "token_id": "699f17ca8434acc547559c68",
                "type": "CREDIT"
            },
            "card_verification_results": {
                "acquirer_merchant_id": "fiservsg_000000809061302",
                "address_verification_result": "MATCH",
                "authorization_code": "831000",
                "cvv_result": "MATCH",
                "network_response_code": "00",
                "network_response_code_descriptor": "Approved and completed sucessfully",
                "network_transaction_id": "016153570198200",
                "reconciliation_id": "7720340188646297003814",
                "retrieval_reference_number": "605615136945",
                "three_d_secure": {
                    "authentication_value": "AAIBBYNoEwAAACcKhAJkdQAAAAA=",
                    "directory_server_trans_id": "f40a41c5-f993-4cc6-804f-78229f07c697",
                    "eci_code": "05",
                    "three_d_secure_flow": "CHALLENGE",
                    "three_d_secure_result": "AUTHENTICATED",
                    "three_d_secure_result_reason": null,
                    "three_d_secure_version": "2.2.0"
                }
            },
            "channel_properties": {
                "cardonfile_type": "CUSTOMER_UNSCHEDULED",
                "failure_return_url": "https://8368-2a09-bac1-1040-8-00-26-78.ngrok-free.app/api/xendit_payments/failure?reference_id=pbp_card_1ed688404833e4ed&iframe=true",
                "skip_three_d_secure": false,
                "success_return_url": "https://8368-2a09-bac1-1040-8-00-26-78.ngrok-free.app/api/xendit_payments/success?reference_id=pbp_card_1ed688404833e4ed&iframe=true",
                "transaction_sequence": "INITIAL"
            },
            "currency": "USD"
        },
        "created": "2026-02-25T15:39:53.716328Z",
        "description": null,
        "direct_bank_transfer": null,
        "direct_debit": null,
        "ewallet": null,
        "id": "pm-94fddee6-3e05-4ba5-a411-350d58b1b7be",
        "metadata": {
            "facility_id": "1",
            "session_purpose": "card_tokenization",
            "user_id": "374"
        },
        "over_the_counter": null,
        "qr_code": null,
        "reference_id": "pbp_card_1ed688404833e4ed_aab69433-e",
        "reusability": "MULTIPLE_USE",
        "status": "ACTIVE",
        "type": "CARD",
        "updated": "2026-02-25T15:40:19.447199Z",
        "virtual_account": null
    },
    "reference_id": "392747ca-d49a-44ab-8a31-fbf095e7fb42",
    "shipping_information": null,
    "status": "REQUIRES_ACTION",
    "updated": "2026-02-25T19:36:16.411447213Z"
}

Esstructura del webhook basico:
{
    "created": "2026-02-26T14:08:13.366Z",
    "business_id": "697388ec8effe7f2421362c4",
    "event": "capture.succeeded",
    "api_version": null,
    "data": {
        "authorized_amount": 400,
        "capturable_amount": 0,
        "captured_amount": 400,
        "channel_properties": null,
        "created": "2026-02-26T14:08:13.321363206Z",
        "currency": "USD",
        "customer_id": null,
        "failure_code": null,
        "id": "cptr-ce3204a7-3388-4860-b334-af1bee7cbd48",
        "metadata": null,
        "payment_id": "cc_69a053cc4d86bdb5cdde16aa",
        "payment_method": {
            "card": {
                "card_data_id": "62f4923cf2e115001a4a255f",
                "card_information": {
                    "cardholder_email": "adan@playbypoint.com",
                    "cardholder_first_name": "adan",
                    "cardholder_last_name": "condori",
                    "cardholder_name": null,
                    "cardholder_phone_number": "+639171234567",
                    "country": "ID",
                    "expiry_month": "10",
                    "expiry_year": "2028",
                    "fingerprint": "62f4923cf2e115001a4a255f",
                    "issuer": "BRI",
                    "masked_card_number": "400000XXXXXX1091",
                    "network": "VISA",
                    "token_id": "699fc04cfa37c927f0f81d20",
                    "type": "CREDIT"
                },
                "card_verification_results": {
                    "three_d_secure": {
                    }
                },
                "channel_properties": {
                },
                "currency": "USD"
            },
            "created": "2026-02-26T03:38:51.61448Z",
            "description": null,
            "direct_bank_transfer": null,
            "direct_debit": null,
            "ewallet": null,
            "id": "pt-e397909c-5380-4fe3-b36c-8966c1a3dcc0",
            "metadata": {
                "facility_id": "1",
                "session_purpose": "card_tokenization",
                "user_id": "374"
            },
            "over_the_counter": null,
            "qr_code": null,
            "reference_id": "pbp_card_572bb111778ef6bc_4f5aba56-4",
            "reusability": "MULTIPLE_USE",
            "status": "ACTIVE",
            "type": "CARD",
            "updated": "2026-02-26T03:39:24.290773Z",
            "virtual_account": null
        },
        "payment_request_id": "pr-19120355-1957-4ef4-bb5b-3634fa08ec8a",
        "reference_id": "pbp_token_9fbade5d9ca5d76d",
        "status": "SUCCEEDED",
        "updated": "2026-02-26T14:08:13.321363206Z"
    }
}
