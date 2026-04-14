package com.quickserve.backend.service;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.WriterException;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import javax.imageio.ImageIO;

@Service
@Slf4j
public class QrCodeService {

    @Value("${app.frontend-url}")
    private String frontendUrl;

    public String generateQrUrl(String qrToken) {
        return frontendUrl + "/scan/" + qrToken;
    }

    /**
     * QR kod PNG resmini Base64 olarak döndürür.
     */
    public String generateQrBase64(String qrToken) {
        String url = generateQrUrl(qrToken);
        try {
            QRCodeWriter writer = new QRCodeWriter();
            Map<EncodeHintType, Object> hints = new HashMap<>();
            hints.put(EncodeHintType.CHARACTER_SET, "UTF-8");
            hints.put(EncodeHintType.MARGIN, 1);

            BitMatrix matrix = writer.encode(url, BarcodeFormat.QR_CODE, 300, 300, hints);
            BufferedImage image = MatrixToImageWriter.toBufferedImage(matrix);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ImageIO.write(image, "PNG", baos);
            return Base64.getEncoder().encodeToString(baos.toByteArray());
        } catch (WriterException | java.io.IOException e) {
            log.error("QR code generation failed for token {}: {}", qrToken, e.getMessage());
            throw new RuntimeException("QR kod oluşturulamadı", e);
        }
    }

    /**
     * QR PNG byte array döndürür (print için).
     */
    public byte[] generateQrBytes(String qrToken) {
        String url = generateQrUrl(qrToken);
        try {
            QRCodeWriter writer = new QRCodeWriter();
            BitMatrix matrix = writer.encode(url, BarcodeFormat.QR_CODE, 400, 400);
            BufferedImage image = MatrixToImageWriter.toBufferedImage(matrix);

            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            ImageIO.write(image, "PNG", baos);
            return baos.toByteArray();
        } catch (WriterException | java.io.IOException e) {
            log.error("QR code generation failed: {}", e.getMessage());
            throw new RuntimeException("QR kod oluşturulamadı", e);
        }
    }
}
