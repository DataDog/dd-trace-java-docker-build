#!/bin/sh
# Import the Datadog CA certificates into the truststore of every JDK
# found under the given search roots (passed as arguments).
set -eux

DD_CERTS_DIR=/usr/local/share/ca-certificates/datadog

# Truststore path pattern compatible with both legacy (JDK 8) and modern JDKs.
JDK_TRUSTSTORE_PATH='*/lib/security/cacerts'

for truststore in $(find -L "$@" -path "${JDK_TRUSTSTORE_PATH}" -type f | sort); do
	java_home="${truststore%/lib/security/cacerts}"
	java_home="${java_home%/jre}"
	keytool="${java_home}/bin/keytool"
	[ -x "${keytool}" ] || continue
	for cert in $(find "${DD_CERTS_DIR}" -type f -name '*.crt' | sort); do
		alias="datadog-$(basename "${cert}" .crt)"
		if "${keytool}" -list -storepass changeit -keystore "${truststore}" -alias "${alias}" >/dev/null 2>&1; then
			"${keytool}" -delete -storepass changeit -keystore "${truststore}" -alias "${alias}"
		fi
		"${keytool}" -importcert -noprompt -trustcacerts -storepass changeit -keystore "${truststore}" -alias "${alias}" -file "${cert}"
	done
done
