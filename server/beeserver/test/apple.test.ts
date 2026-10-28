import "reflect-metadata";
import * as x509 from "@peculiar/x509";
import { describe, expect, it } from "vitest";
import { NotApple, verifyTransaction } from "../src/apple";

x509.cryptoProvider.set(crypto);

const alg = { name: "ECDSA", namedCurve: "P-256", hash: "SHA-256" } as const;
const b64url = (data: ArrayBuffer | Uint8Array) =>
  btoa(String.fromCharCode(...new Uint8Array(data))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const der = (cert: x509.X509Certificate) => btoa(String.fromCharCode(...new Uint8Array(cert.rawData)));
const mark = (oid: string) => new x509.Extension(oid, false, new Uint8Array([5, 0]));

/// A chain shaped as Apple's: a root, an intermediate and a leaf, with or without Apple's marks.
async function chain(marks = true) {
  const keys = await Promise.all([0, 1, 2].map(() => crypto.subtle.generateKey(alg, true, ["sign", "verify"]) as Promise<CryptoKeyPair>));
  const day = 86_400_000;
  const dates = { notBefore: new Date(Date.now() - day), notAfter: new Date(Date.now() + 365 * day) };
  const root = await x509.X509CertificateGenerator.createSelfSigned({ serialNumber: "01", name: "CN=Test Root", keys: keys[0], signingAlgorithm: alg, ...dates });
  const intermediate = await x509.X509CertificateGenerator.create({
    serialNumber: "02", subject: "CN=Test Intermediate", issuer: root.subject, publicKey: keys[1].publicKey, signingKey: keys[0].privateKey,
    signingAlgorithm: alg, extensions: marks ? [mark("1.2.840.113635.100.6.2.1")] : [], ...dates,
  });
  const leaf = await x509.X509CertificateGenerator.create({
    serialNumber: "03", subject: "CN=Test Leaf", issuer: intermediate.subject, publicKey: keys[2].publicKey, signingKey: keys[1].privateKey,
    signingAlgorithm: alg, extensions: marks ? [mark("1.2.840.113635.100.6.11.1")] : [], ...dates,
  });
  return { root, intermediate, leaf, signer: keys[2].privateKey };
}

async function sign(payload: object, c: Awaited<ReturnType<typeof chain>>) {
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", x5c: [der(c.leaf), der(c.intermediate), der(c.root)] })));
  const body = b64url(new TextEncoder().encode(JSON.stringify(payload)));
  const signature = await crypto.subtle.sign(alg, c.signer, new TextEncoder().encode(header + "." + body));
  return `${header}.${body}.${b64url(signature)}`;
}

const purchase = {
  transactionId: "2000000111", originalTransactionId: "2000000100", bundleId: "de.chille.causabee",
  productId: "de.chille.causabee.pro.monthly", purchaseDate: Date.now(), expiresDate: Date.now() + 30 * 86_400_000,
  environment: "Sandbox", type: "Auto-Renewable Subscription",
};

describe("a purchase as the App Store signed it", () => {
  it("is read when the chain ends at the root and the signature holds", async () => {
    const c = await chain();
    const t = await verifyTransaction(await sign(purchase, c), der(c.root));
    expect(t.originalTransactionId).toBe("2000000100");
    expect(t.productId).toBe("de.chille.causabee.pro.monthly");
  });

  it("is refused when its root is not the one trusted", async () => {
    const c = await chain(), other = await chain();
    await expect(verifyTransaction(await sign(purchase, c), der(other.root))).rejects.toThrow(NotApple);
  });

  it("is refused when the certificates lack Apple's marks", async () => {
    const c = await chain(false);
    await expect(verifyTransaction(await sign(purchase, c), der(c.root))).rejects.toThrow(NotApple);
  });

  it("is refused when the purchase was changed after signing", async () => {
    const c = await chain();
    const [h, , s] = (await sign(purchase, c)).split(".");
    const forged = b64url(new TextEncoder().encode(JSON.stringify({ ...purchase, expiresDate: Date.now() + 999 * 86_400_000 })));
    await expect(verifyTransaction(`${h}.${forged}.${s}`, der(c.root))).rejects.toThrow(NotApple);
  });

  it("is refused, not a fault, when it cannot even be read", async () => {
    await expect(verifyTransaction("a.b.c")).rejects.toThrow(NotApple);
    await expect(verifyTransaction("nonsense")).rejects.toThrow(NotApple);
  });

  it("is refused by default unless Apple signed it", async () => {
    const c = await chain();
    await expect(verifyTransaction(await sign(purchase, c))).rejects.toThrow(NotApple);
  });
});
