package com.example.server.service;

import com.example.server.dto.AnalysisResult;
import com.example.server.dto.VideoContext;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class EvidenceVerificationServiceTest {

    private final EvidenceVerificationService service = new EvidenceVerificationService();
    private final VideoContext context = new VideoContext(
            "lesson.mp4",
            "总结课程",
            List.of(new VideoContext.VideoSegment(
                    120_000,
                    180_000,
                    "接下来讲解二叉树的前序遍历",
                    List.of("前序遍历：根节点、左子树、右子树"),
                    List.of("frame_000125.jpg"))));

    @Test
    void acceptsVerbatimEvidenceAtTheDeclaredTimestamp() {
        AnalysisResult.Evidence evidence = new AnalysisResult.Evidence(
                125_000, "OCR", "根节点、左子树、右子树", "前序遍历顺序");

        assertTrue(service.supported(context, evidence));
        assertTrue(service.supportsClaim(context, "前序遍历顺序", evidence));
    }

    @Test
    void rejectsTextThatOnlyLooksSimilarToTheSource() {
        AnalysisResult.Evidence evidence = new AnalysisResult.Evidence(
                125_000, "OCR", "根节点左子树不存在，因此应跳过", "前序遍历顺序");

        assertFalse(service.supported(context, evidence));
    }
    @Test
    void acceptsZeroAndSharedTimestampsWithoutInventingPrecision() {
        VideoContext shortContext = new VideoContext("workflow.mp4", "步骤和恢复点", List.of(
                new VideoContext.VideoSegment(0, 60_000, "", List.of(
                        "Upload the file. Failure: resume from last successful checkpoint"), List.of())));
        AnalysisResult.Evidence step = new AnalysisResult.Evidence(0, "OCR", "Upload the file", "上传文件");
        AnalysisResult.Evidence recovery = new AnalysisResult.Evidence(0, "OCR",
                "resume from last successful checkpoint", "从最后成功检查点恢复");
        assertTrue(service.supportsClaim(shortContext, "上传文件", step));
        assertTrue(service.supportsClaim(shortContext, "从最后成功检查点恢复", recovery));
    }

    @Test
    void rejectsRealTextAtAnUncoveredTimestamp() {
        assertFalse(service.supported(context, new AnalysisResult.Evidence(
                0, "OCR", "根节点、左子树、右子树", "前序遍历顺序")));
    }

    @Test
    void rejectsEvidenceBoundToADifferentClaim() {
        assertFalse(service.supportsClaim(context, "恢复检查点", new AnalysisResult.Evidence(
                125_000, "OCR", "根节点、左子树、右子树", "前序遍历顺序")));
    }
    @Test
    void reportsActualBindingsInsteadOfArrayPositions() {
        AnalysisResult.Evidence evidence = new AnalysisResult.Evidence(
                125_000, "OCR", "根节点、左子树、右子树", "前序遍历顺序");
        AnalysisResult result = new AnalysisResult("标题", List.of("其他结论", "前序遍历顺序"),
                List.of(evidence), List.of(), List.of());
        var check = service.inspect(context, result).getFirst();
        assertTrue(check.boundConclusionIndexes().equals(List.of(1)));
        assertTrue(check.timestampCovered());
        assertTrue(check.sourceTextVerified());
    }

    @Test
    void reportDoesNotHideAnInvalidTimestampOrBinding() {
        AnalysisResult result = new AnalysisResult("标题", List.of("恢复点"), List.of(
                new AnalysisResult.Evidence(0, "OCR", "根节点、左子树、右子树", "前序遍历顺序")),
                List.of(), List.of());
        var check = service.inspect(context, result).getFirst();
        assertTrue(check.boundConclusionIndexes().isEmpty());
        assertFalse(check.timestampCovered());
        assertFalse(check.sourceTextVerified());
    }
}
