package app.vibemusic.api;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import java.util.Map;
@RestControllerAdvice
public class ApiErrors {
 @ExceptionHandler(ApiException.class) ResponseEntity<?> api(ApiException e){return ResponseEntity.status(e.getStatus()).body(Map.of("error",e.getCode(),"message",e.getMessage(),"status",e.getStatus()));}
 @ExceptionHandler({MethodArgumentNotValidException.class,ConstraintViolationException.class,IllegalArgumentException.class,HttpMessageNotReadableException.class,MissingServletRequestParameterException.class,MethodArgumentTypeMismatchException.class}) ResponseEntity<?> invalid(Exception e){return ResponseEntity.badRequest().body(Map.of("error","INVALID_REQUEST","message",e.getMessage()==null?"Request is invalid":e.getMessage(),"status",400));}
 @ExceptionHandler(Exception.class) ResponseEntity<?> unexpected(Exception e){return ResponseEntity.internalServerError().body(Map.of("error","INTERNAL_ERROR","message","Request could not be completed","status",500));}
}
