{{- define "imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.global.imagecredential.registry (printf "%s:%s" .Values.global.imagecredential.username .Values.global.imagecredential.password | b64enc) | b64enc }}
{{- end }}
