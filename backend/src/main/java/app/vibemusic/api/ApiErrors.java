package app.vibemusic.api;
import jakarta.validation.ConstraintViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
@RestControllerAdvice
public class ApiErrors {
 private static final Logger log=LoggerFactory.getLogger(ApiErrors.class);
 @ExceptionHandler(ApiException.class) ResponseEntity<?> api(ApiException e){return ResponseEntity.status(e.getStatus()).body(Map.of("error",e.getCode(),"message",e.getMessage(),"status",e.getStatus()));}
 @ExceptionHandler(RestClientResponseException.class) ResponseEntity<?> upstream(RestClientResponseException e){int upstreamStatus=e.getStatusCode().value();log.warn("Spotify API request failed with HTTP {}: {}",upstreamStatus,e.getResponseBodyAsString());int status=upstreamStatus==429?429:502;String message=upstreamStatus==429?"Spotify rate limit reached. Try again shortly.":"Spotify API rejected the request (HTTP "+upstreamStatus+").";return ResponseEntity.status(status).body(Map.of("error","SPOTIFY_REQUEST_FAILED","message",message,"status",status));}
 @ExceptionHandler({MethodArgumentNotValidException.class,ConstraintViolationException.class,IllegalArgumentException.class,HttpMessageNotReadableException.class,MissingServletRequestParameterException.class,MethodArgumentTypeMismatchException.class}) ResponseEntity<?> invalid(Exception e){return ResponseEntity.badRequest().body(Map.of("error","INVALID_REQUEST","message",e.getMessage()==null?"Request is invalid":e.getMessage(),"status",400));}
 @ExceptionHandler(Exception.class) ResponseEntity<?> unexpected(Exception e){log.error("Unhandled API request failure",e);return ResponseEntity.internalServerError().body(Map.of("error","INTERNAL_ERROR","message","Request could not be completed","status",500));}
}
