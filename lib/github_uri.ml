open Bos_setup

let to_github_standard uri =
  match Uri_helpers.get_domain uri with
  | [ "io"; "github"; user ] -> (
      match Text.split_uri ~rel:true uri with
      | None -> R.error_msgf "invalid uri: %s" uri
      | Some (_, _, path) -> Ok ("https://github.com/" ^ user ^ "/" ^ path))
  | _ -> Ok uri

let get_user_and_repo uri =
  let uri_format_error =
    R.msgf
      "Could not derive user and repo from uri %a; expected the pattern \
       $SCHEME://$HOST/$USER/$REPO[.$EXT][/$DIR]"
      String.dump uri
  in
  let uri_scheme_error =
    R.msgf "The following uri is expected to be a web address: %a" String.dump
      uri
  in
  match Text.split_uri ~rel:true uri with
  | None -> Error uri_format_error
  | Some ("file:", _, _) -> Error uri_scheme_error
  | Some (_, _, path) -> (
      if path = "" then Error uri_format_error
      else
      match String.cut ~sep:"/" path with
      | None -> Error uri_format_error
      | Some (user, path) ->
          let repo =
            match String.cut ~sep:"/" path with
            | None -> path
            | Some (repo, _) -> repo
          in
          Fpath.of_string repo
          >>= (fun repo -> Ok (user, Fpath.(to_string @@ rem_ext repo)))
          |> R.reword_error_msg (fun _ -> uri_format_error))

let split_doc_uri uri =
  let uri_error uri =
    R.msgf
      "Could not derive publication directory $PATH from opam doc field \
       value %a; expected the pattern $SCHEME://$USER.github.io/$REPO/$PATH"
      String.dump uri
  in
  match Text.split_uri ~rel:true uri with
  | None -> Error (uri_error uri)
  | Some (_, host, path) -> (
      if path = "" then Error (uri_error uri)
      else
      (match String.cut ~sep:"." host with
      | Some (user, g) when String.equal g "github.io" -> Ok user
      | _ -> Error (uri_error uri))
      >>= fun user ->
      match String.cut ~sep:"/" path with
      | None -> Ok (user, path, Fpath.v ".")
      | Some (repo, "") -> Ok (user, repo, Fpath.v ".")
      | Some (repo, path) ->
          Fpath.of_string path
          >>| (fun p -> (user, repo, Fpath.rem_empty_seg p))
          |> R.reword_error_msg (fun _ -> uri_error uri))
