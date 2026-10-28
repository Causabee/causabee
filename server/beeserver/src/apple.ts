// A purchase as the App Store signed it: the app sends the transaction it got from StoreKit — a
// JWS — and the server believes it only once Apple's signature holds, up to Apple's own root
// certificate. No key of Apple's is needed for this, and nothing is asked of Apple's servers.

import "reflect-metadata";
import * as x509 from "@peculiar/x509";

x509.cryptoProvider.set(crypto);

/// Apple Root CA - G3, from apple.com/certificateauthority — SHA-256
/// 63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79.
export const appleRootG3 = "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==";

/// What the server reads of a transaction.
export interface AppleTransaction {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  expiresDate?: number;
  revocationDate?: number;
  environment: string;
  type: string;
}

export class NotApple extends Error {}

const bytes = (b64url: string) => Uint8Array.from(atob(b64url.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(b64url.length / 4) * 4, "=")), (c) => c.charCodeAt(0));
const text = (b64url: string) => new TextDecoder().decode(bytes(b64url));

/// The transaction, once its signature and its chain hold. `root` is Apple's, but for a test.
export async function verifyTransaction(jws: string, root = appleRootG3, now = new Date()): Promise<AppleTransaction> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new NotApple("not a JWS");
  const header = JSON.parse(text(parts[0]));
  if (header.alg !== "ES256" || !Array.isArray(header.x5c) || header.x5c.length !== 3) throw new NotApple("not signed as Apple signs");
  const [leaf, intermediate, top] = header.x5c.map((c: string) => new x509.X509Certificate(c));
  const anchor = new x509.X509Certificate(root);
  // The chain ends at Apple's root, byte for byte — not at a root that only names itself so.
  const same = (a: x509.X509Certificate, b: x509.X509Certificate) =>
    a.rawData.byteLength === b.rawData.byteLength && new Uint8Array(a.rawData).every((v, i) => v === new Uint8Array(b.rawData)[i]);
  if (!same(top, anchor)) throw new NotApple("not Apple's root");
  // Apple's marks: the intermediate is the one for Apple's own services, the leaf the App Store's
  // receipt signer — a certificate of another kind under the same root does not count.
  if (!intermediate.getExtension("1.2.840.113635.100.6.2.1")) throw new NotApple("intermediate is not Apple's");
  if (!leaf.getExtension("1.2.840.113635.100.6.11.1")) throw new NotApple("leaf is not the App Store's");
  if (!(await intermediate.verify({ publicKey: anchor.publicKey, date: now }))) throw new NotApple("intermediate not signed by the root");
  if (!(await leaf.verify({ publicKey: intermediate.publicKey, date: now }))) throw new NotApple("leaf not signed by the intermediate");
  const key = await leaf.publicKey.export({ name: "ECDSA", namedCurve: "P-256" }, ["verify"]);
  const signed = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, bytes(parts[2]), new TextEncoder().encode(parts[0] + "." + parts[1]));
  if (!signed) throw new NotApple("signature does not hold");
  return JSON.parse(text(parts[1])) as AppleTransaction;
}
